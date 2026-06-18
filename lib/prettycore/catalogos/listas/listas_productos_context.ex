defmodule Prettycore.Catalogos.Listas.ListasProductosContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Listas.{ListaProductos, ListaProductosItem}
  alias Prettycore.Catalogos.Productos.Producto

  def listar_listas(offset, limit) do
    ListaProductos |> offset(^offset) |> limit(^limit) |> Repo.all()
  end

  def count_listas, do: Repo.aggregate(ListaProductos, :count)

  def listar_listas_por_cliente(cliente_id, offset, limit) do
    ListaProductos
    |> where([l], l.cliente_id == ^cliente_id)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_listas_por_cliente(cliente_id) do
    ListaProductos |> where([l], l.cliente_id == ^cliente_id) |> Repo.aggregate(:count)
  end

  def obtener_lista(id), do: Repo.get(ListaProductos, id)

  def obtener_lista_con_productos(id) do
    case Repo.get(ListaProductos, id) do
      nil   -> nil
      lista ->
        producto_ids =
          ListaProductosItem
          |> where([i], i.lista_id == ^lista.id)
          |> select([i], i.producto_id)
          |> Repo.all()

        productos = Producto |> where([p], p.id in ^producto_ids) |> Repo.all()
        Map.put(lista, :productos, productos)
    end
  end

  def buscar_lista(id) do
    case obtener_lista(id) do
      nil   -> {:error, :not_found}
      lista -> {:ok, lista}
    end
  end

  def crear_lista(attrs) do
    %ListaProductos{} |> ListaProductos.changeset(attrs) |> Repo.insert()
  end

  def actualizar_lista(%ListaProductos{} = lista, attrs) do
    lista |> ListaProductos.changeset(attrs) |> Repo.update()
  end

  def agregar_producto(lista_id, producto_id) do
    %ListaProductosItem{}
    |> ListaProductosItem.changeset(%{"lista_id" => lista_id, "producto_id" => producto_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:lista_id, :producto_id])
  end

  def quitar_producto(lista_id, producto_id) do
    case Repo.get_by(ListaProductosItem, lista_id: lista_id, producto_id: producto_id) do
      nil  -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end
end
