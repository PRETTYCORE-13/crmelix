defmodule Prettycore.Carritos do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Carritos.{Carrito, CarritoItem}
  alias Prettycore.Productos.Producto
  alias Prettycore.ProductosNativos.ProductoNativo

  @doc "Retorna el carrito activo del usuario con sus items y productos cargados."
  def get_carrito(user_id) do
    items_query = from i in CarritoItem, order_by: [asc: i.inserted_at]

    carrito =
      Repo.one(
        from c in Carrito,
          where: c.user_id == ^user_id and c.estado == "activo",
          preload: [items: ^items_query]
      )

    case carrito do
      nil ->
        %{carrito: nil, items: [], total_items: 0}

      c ->
        codigos = Enum.map(c.items, & &1.producto_codigo)

        frog_map =
          Repo.all(from p in Producto, where: p.codigo in ^codigos, select: p)
          |> Map.new(& {&1.codigo, %{descripcion: &1.descripcion, imagen_url: &1.imagen_url}})

        nativos_map =
          Repo.all(from p in ProductoNativo, where: p.codigo in ^codigos, select: p)
          |> Map.new(& {&1.codigo, %{descripcion: &1.descripcion, imagen_url: &1.imagen_url}})

        productos_map = Map.merge(frog_map, nativos_map)

        items =
          Enum.map(c.items, fn item ->
            Map.put(item, :producto, Map.get(productos_map, item.producto_codigo))
          end)

        total_items = Enum.sum(Enum.map(items, & &1.cantidad))
        %{carrito: c, items: items, total_items: total_items}
    end
  end

  @doc "Agrega un producto al carrito activo (o crea el carrito si no existe). Si ya existe, incrementa la cantidad."
  def add_item(user_id, producto_codigo, cantidad \\ 1) do
    carrito = get_or_create_carrito!(user_id)

    case Repo.get_by(CarritoItem, carrito_id: carrito.id, producto_codigo: producto_codigo) do
      nil ->
        %CarritoItem{}
        |> CarritoItem.changeset(%{
          carrito_id: carrito.id,
          producto_codigo: producto_codigo,
          cantidad: cantidad
        })
        |> Repo.insert()

      item ->
        item
        |> CarritoItem.changeset(%{cantidad: item.cantidad + cantidad})
        |> Repo.update()
    end
  end

  @doc "Actualiza la cantidad de un item. Si cantidad == 0 lo elimina."
  def update_cantidad(item_id, cantidad) when cantidad > 0 do
    case Repo.get(CarritoItem, item_id) do
      nil -> {:error, :not_found}
      item -> item |> CarritoItem.changeset(%{cantidad: cantidad}) |> Repo.update()
    end
  end

  def update_cantidad(item_id, 0), do: remove_item(item_id)

  @doc "Elimina un item del carrito."
  def remove_item(item_id) do
    case Repo.get(CarritoItem, item_id) do
      nil -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end

  @doc "Vacía todos los items del carrito activo del usuario."
  def vaciar_carrito(user_id) do
    case Repo.one(from c in Carrito, where: c.user_id == ^user_id and c.estado == "activo") do
      nil -> :ok
      carrito ->
        Repo.delete_all(from i in CarritoItem, where: i.carrito_id == ^carrito.id)
        :ok
    end
  end

  defp get_or_create_carrito!(user_id) do
    case Repo.one(from c in Carrito, where: c.user_id == ^user_id and c.estado == "activo") do
      nil ->
        {:ok, carrito} =
          %Carrito{}
          |> Carrito.changeset(%{user_id: user_id, estado: "activo"})
          |> Repo.insert()
        carrito

      carrito ->
        carrito
    end
  end
end
