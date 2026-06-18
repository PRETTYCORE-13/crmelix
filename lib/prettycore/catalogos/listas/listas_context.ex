defmodule Prettycore.Catalogos.Listas.ListasContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Listas.{Lista, ListaItem}

  def listar_listas(offset, limit) do
    Lista |> offset(^offset) |> limit(^limit) |> Repo.all()
  end

  def count_listas, do: Repo.aggregate(Lista, :count)

  def listar_listas_por_cliente(cliente_id, offset, limit) do
    Lista
    |> where([l], l.cliente_id == ^cliente_id)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_listas_por_cliente(cliente_id) do
    Lista |> where([l], l.cliente_id == ^cliente_id) |> Repo.aggregate(:count)
  end

  def obtener_lista(id), do: Repo.get(Lista, id)

  def obtener_lista_con_productos(id) do
    case Repo.get(Lista, id) do
      nil   -> nil
      lista ->
        producto_ids =
          ListaItem
          |> where([i], i.lista_id == ^lista.id)
          |> select([i], i.producto_id)
          |> Repo.all()

        productos =
          Prettycore.Catalogos.Productos.Producto
          |> where([p], p.id in ^producto_ids)
          |> Repo.all()

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
    %Lista{} |> Lista.changeset(attrs) |> Repo.insert()
  end

  def actualizar_lista(%Lista{} = lista, attrs) do
    lista |> Lista.changeset(attrs) |> Repo.update()
  end

  def agregar_producto(lista_id, producto_id) do
    %ListaItem{}
    |> ListaItem.changeset(%{"lista_id" => lista_id, "producto_id" => producto_id})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:lista_id, :producto_id])
  end

  def quitar_producto(lista_id, producto_id) do
    case Repo.get_by(ListaItem, lista_id: lista_id, producto_id: producto_id) do
      nil  -> {:error, :not_found}
      item -> Repo.delete(item)
    end
  end
end
