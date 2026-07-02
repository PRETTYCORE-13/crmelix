defmodule Prettycore.BI.ProductosContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.BI.Producto

  def count_productos, do: Repo.aggregate(Producto, :count)

  def count_productos(filtros) do
    Producto
    |> aplicar_filtros(filtros)
    |> Repo.aggregate(:count)
  end

  def listar_productos(offset, limit, filtros \\ %{}) do
    Producto
    |> aplicar_filtros(filtros)
    |> order_by([p], asc: p.id_producto)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  def obtener_producto(id), do: Repo.get(Producto, id)

  def buscar_producto(id) do
    case obtener_producto(id) do
      nil      -> {:error, :not_found}
      producto -> {:ok, producto}
    end
  end

  def crear_producto(attrs) do
    %Producto{}
    |> Producto.changeset(attrs)
    |> Repo.insert()
  end

  def insertar_productos(lista) when is_list(lista) do
    Repo.insert_all(Producto, lista, on_conflict: :nothing)
  end

  defp aplicar_filtros(query, filtros) do
    Enum.reduce(filtros, query, fn
      {"id_producto", id}, q     -> where(q, [p], p.id_producto == ^id)
      {"nombre_producto", n}, q  -> where(q, [p], ilike(p.nombre_producto, ^"%#{n}%"))
      {"fabricante", f}, q       -> where(q, [p], p.fabricante == ^f)
      {"marca", m}, q            -> where(q, [p], p.marca == ^m)
      _, q -> q
    end)
  end
end
