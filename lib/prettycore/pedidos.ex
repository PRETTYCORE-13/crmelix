defmodule Prettycore.Pedidos do
  @moduledoc """
  Gestión de pedidos. Funciona de forma independiente de APIs externas,
  toda la información se persiste en PostgreSQL.
  """
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Pedidos.{Pedido, PedidoItem}

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

  @doc "Devuelve true si el producto tiene pedidos en estado pendiente o procesando."
  def producto_en_pedido_activo?(producto_codigo) do
    Repo.exists?(
      from i in PedidoItem,
        join: p in Pedido, on: p.id == i.pedido_id,
        where: i.producto_codigo == ^producto_codigo and p.estado in ^@estados_activos
    )
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
  def crear_desde_carrito(user_id, cart_items, precios, cliente_codigo \\ nil, dir_codigo \\ nil) do
    Repo.transaction(fn ->
      {:ok, pedido} =
        %Pedido{}
        |> Pedido.changeset(%{
          user_id: user_id,
          cliente_codigo: cliente_codigo,
          dir_codigo: dir_codigo,
          estado: "pendiente"
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

      Repo.preload(pedido, :items)
    end)
  end

  @doc "Cambia el estado de un pedido."
  def cambiar_estado(pedido_id, nuevo_estado) do
    case Repo.get(Pedido, pedido_id) do
      nil -> {:error, :not_found}
      pedido ->
        pedido
        |> Pedido.changeset(%{estado: nuevo_estado})
        |> Repo.update()
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
