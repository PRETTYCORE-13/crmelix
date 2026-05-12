defmodule Prettycore.Pedidos do
  @moduledoc """
  Gestión de pedidos. Funciona de forma independiente de APIs externas,
  toda la información se persiste en PostgreSQL.
  """
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Pedidos.{Pedido, PedidoItem, UserAddress}

  @doc "Lista pedidos del usuario (cliente ve los suyos; admin/oficina/sysadmin ve todos)."
  def list_pedidos(user_id, role) when role in ["admin", "sysadmin", "oficina"] do
    Repo.all(
      from p in Pedido,
        order_by: [desc: p.inserted_at],
        preload: :items
    )
  end

  def list_pedidos(user_id, _role) do
    Repo.all(
      from p in Pedido,
        where: p.user_id == ^user_id,
        order_by: [desc: p.inserted_at],
        preload: :items
    )
  end

  @estados_activos ["pendiente", "procesando"]

  @transiciones_validas %{
    "pendiente"              => ~w(procesando cancelado),
    "procesando"             => ~w(enviado cancelado),
    "enviado"                => ~w(entregado),
    "entregado"              => [],
    "cancelado"              => [],
    "cancelacion_solicitada" => ~w(cancelado pendiente)
  }

  @doc "Suma el total de pedidos a crédito activos (pendiente/procesando) de un usuario."
  def credito_usado(user_id) do
    result =
      Repo.one(
        from i in PedidoItem,
          join: p in Pedido, on: p.id == i.pedido_id,
          where:
            p.user_id == ^user_id and
            p.metodo_pago == "credito" and
            p.estado in ^@estados_activos,
          select: sum(i.precio_unitario * i.cantidad)
      )
    case result do
      nil              -> Decimal.new(0)
      %Decimal{} = d   -> d
      f when is_float(f) -> Decimal.from_float(f)
      i when is_integer(i) -> Decimal.new(i)
    end
  end

  @doc "Devuelve true si el producto tiene pedidos en estado pendiente o procesando."
  def producto_en_pedido_activo?(producto_codigo) do
    Repo.exists?(
      from i in PedidoItem,
        join: p in Pedido, on: p.id == i.pedido_id,
        where: i.producto_codigo == ^producto_codigo and p.estado in ^@estados_activos
    )
  end

  @doc """
  Devuelve las direcciones guardadas del usuario como lista de mapas:
  %{id: uuid_or_nil, display: string, form: map_or_nil}
  """
  def list_direcciones_guardadas(user_id) do
    saved =
      Repo.all(
        from a in UserAddress,
          where: a.user_id == ^user_id,
          order_by: [desc: a.inserted_at]
      )
      |> Enum.uniq_by(& &1.direccion)
      |> Enum.map(&%{id: &1.id, display: &1.direccion, form: &1.form_data})

    saved_displays = MapSet.new(saved, & &1.display)

    from_orders =
      Repo.all(
        from p in Pedido,
          where: p.user_id == ^user_id and not is_nil(p.direccion_envio) and p.direccion_envio != "",
          group_by: p.direccion_envio,
          select: p.direccion_envio,
          order_by: [desc: max(p.inserted_at)],
          limit: 4
      )
      |> Enum.reject(&MapSet.member?(saved_displays, &1))
      |> Enum.map(&%{id: nil, display: &1, form: nil})

    (saved ++ from_orders) |> Enum.take(4)
  end

  @doc "Persiste una dirección con sus datos de formulario (idempotente por contenido)."
  def guardar_direccion_usuario(user_id, direccion, form_data \\ nil) do
    case Repo.one(from a in UserAddress, where: a.user_id == ^user_id and a.direccion == ^direccion) do
      nil ->
        %UserAddress{}
        |> UserAddress.changeset(%{user_id: user_id, direccion: direccion, form_data: form_data})
        |> Repo.insert()
      existing ->
        {:ok, existing}
    end
  end

  @doc "Elimina una dirección guardada del usuario por id."
  def eliminar_dir_usuario(id) do
    Repo.delete_all(from a in UserAddress, where: a.id == ^id)
  end

  @doc "Obtiene un pedido por id con sus items."
  def get_pedido(id) do
    Repo.one(from p in Pedido, where: p.id == ^id, preload: :items)
  end

  @doc """
  Crea un pedido desde el carrito activo del usuario.
  Recibe lista de items del carrito y mapa de precios.
  Devuelve {:ok, pedido} | {:error, changeset}.
  """
  def crear_desde_carrito(user_id, cart_items, precios, cliente_codigo \\ nil, dir_codigo \\ nil, metodo_pago \\ "contado", sucursal_num \\ nil, limite_credito \\ nil, direccion_envio \\ nil) do
    Repo.transaction(fn ->
      # Re-validar crédito dentro de la transacción para evitar race condition
      if metodo_pago == "credito" and limite_credito != nil do
        usado = credito_usado(user_id)
        total_orden =
          Enum.reduce(cart_items, 0.0, fn item, acc ->
            acc + (Map.get(precios, item.producto_codigo) || 0) * item.cantidad
          end)
        disponible = Decimal.sub(limite_credito, Decimal.round(usado, 2))
        if Decimal.compare(Decimal.round(Decimal.from_float(total_orden), 2), disponible) == :gt do
          Repo.rollback(:credito_excedido)
        end
      end

      {:ok, pedido} =
        %Pedido{}
        |> Pedido.changeset(%{
          user_id: user_id,
          cliente_codigo: cliente_codigo,
          dir_codigo: dir_codigo,
          estado: "pendiente",
          metodo_pago: metodo_pago,
          direccion_envio: direccion_envio
        })
        |> Repo.insert()

      Enum.each(cart_items, fn item ->
        precio = Map.get(precios, item.producto_codigo) || Map.get(precios, "0") || 0.0
        descripcion = item.producto && item.producto.descripcion

        %PedidoItem{}
        |> PedidoItem.changeset(%{
          pedido_id: pedido.id,
          producto_codigo: item.producto_codigo,
          descripcion: descripcion,
          cantidad: item.cantidad,
          precio_unitario: precio
        })
        |> Repo.insert!()
      end)

      if sucursal_num do
        Enum.each(cart_items, fn item ->
          case Prettycore.StockSucursal.decrement_stock(item.producto_codigo, sucursal_num, item.cantidad) do
            :ok -> :ok
            {:error, :insufficient_stock} -> Repo.rollback({:stock_insuficiente, item.producto_codigo})
          end
        end)
      end

      Repo.preload(pedido, :items)
    end)
  end

  @doc "Cambia el estado de un pedido respetando las transiciones válidas."
  def cambiar_estado(pedido_id, nuevo_estado) do
    case Repo.get(Pedido, pedido_id) do
      nil -> {:error, :not_found}
      pedido ->
        estados_ok = Map.get(@transiciones_validas, pedido.estado, [])
        if nuevo_estado in estados_ok do
          pedido |> Pedido.changeset(%{estado: nuevo_estado}) |> Repo.update()
        else
          {:error, :transicion_invalida}
        end
    end
  end

  @doc "Solicita cancelación de un pedido (cliente). Queda en espera de aprobación del admin."
  def solicitar_cancelacion(pedido_id) do
    case Repo.get(Pedido, pedido_id) do
      nil -> {:error, :not_found}
      %{estado: e} = p when e in ["pendiente", "procesando"] ->
        p |> Pedido.changeset(%{estado: "cancelacion_solicitada"}) |> Repo.update()
      _ -> {:error, :no_cancelable}
    end
  end

  @doc "Cancela un pedido directamente (admin)."
  def cancelar(pedido_id) do
    case Repo.get(Pedido, pedido_id) do
      nil -> {:error, :not_found}
      %{estado: e} = p when e in ["pendiente", "procesando", "cancelacion_solicitada"] ->
        p |> Pedido.changeset(%{estado: "cancelado"}) |> Repo.update()
      _ -> {:error, :no_cancelable}
    end
  end
end
