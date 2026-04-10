defmodule Prettycore.StockSucursal do
  @moduledoc "Gestión de stock por sucursal."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.StockSucursal.StockItem

  @doc "Devuelve %{producto_codigo => cantidad} para una sucursal."
  def get_stock_map(sucursal_numero) do
    PsqlRepo.all(
      from s in StockItem,
        where: s.sucursal_numero == ^sucursal_numero,
        select: {s.producto_codigo, s.cantidad}
    )
    |> Map.new()
  end

  @doc "Inserta o actualiza el stock de un producto en una sucursal."
  def upsert_stock(producto_codigo, sucursal_numero, cantidad) do
    existing =
      PsqlRepo.one(
        from s in StockItem,
          where: s.producto_codigo == ^producto_codigo and s.sucursal_numero == ^sucursal_numero
      )

    case existing do
      nil ->
        %StockItem{}
        |> StockItem.changeset(%{
          producto_codigo: producto_codigo,
          sucursal_numero: sucursal_numero,
          cantidad: cantidad
        })
        |> PsqlRepo.insert()

      item ->
        item
        |> StockItem.changeset(%{cantidad: cantidad})
        |> PsqlRepo.update()
    end
  end

  @doc "Guarda múltiples entradas de stock: recibe %{producto_codigo => cantidad_string}."
  def guardar_stock(sucursal_numero, edits) do
    Enum.each(edits, fn {codigo, cant_str} ->
      cantidad = case Integer.parse(to_string(cant_str)) do
        {n, _} when n >= 0 -> n
        _ -> 0
      end
      upsert_stock(codigo, sucursal_numero, cantidad)
    end)
  end
end
