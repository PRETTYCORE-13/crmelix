defmodule Prettycore.Apis.VentasContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Apis.Venta

  def count_ventas, do: Repo.aggregate(Venta, :count)

  def count_ventas(filtros) do
    Venta
    |> aplicar_filtros(filtros)
    |> Repo.aggregate(:count)
  end

  def listar_ventas(offset, limit, filtros \\ %{}) do
    Venta
    |> aplicar_filtros(filtros)
    |> order_by([v], desc: v.fecha_liq)
    |> offset(^offset)
    |> limit(^limit)
    |> Repo.all()
  end

  def obtener_venta(id), do: Repo.get(Venta, id)

  def buscar_venta(id) do
    case obtener_venta(id) do
      nil   -> {:error, :not_found}
      venta -> {:ok, venta}
    end
  end

  def crear_venta(attrs) do
    %Venta{}
    |> Venta.changeset(attrs)
    |> Repo.insert()
  end

  def insertar_ventas(lista) when is_list(lista) do
    Repo.insert_all(Venta, lista, on_conflict: :nothing)
  end

  defp aplicar_filtros(query, filtros) do
    Enum.reduce(filtros, query, fn
      {"fecha_desde", fecha}, q ->
        case Date.from_iso8601(fecha) do
          {:ok, d} -> where(q, [v], v.fecha_liq >= ^d)
          _        -> q
        end

      {"fecha_hasta", fecha}, q ->
        case Date.from_iso8601(fecha) do
          {:ok, d} -> where(q, [v], v.fecha_liq <= ^d)
          _        -> q
        end

      {"id_cliente", id}, q  -> where(q, [v], v.id_cliente == ^id)
      {"id_producto", id}, q -> where(q, [v], v.id_producto == ^id)
      {"udn", udn}, q        -> where(q, [v], v.udn == ^udn)
      {"ruta_prev", r}, q    -> where(q, [v], v.ruta_prev == ^r)

      _, q -> q
    end)
  end
end
