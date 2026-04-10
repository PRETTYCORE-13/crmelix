defmodule Prettycore.ListasPrecios do
  @moduledoc "Gestión de listas de precios nativas (independientes de la API externa)."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.ListasPrecios.ListaPrecio

  @doc "Números de lista existentes, ordenados."
  def numeros_disponibles do
    PsqlRepo.all(from lp in ListaPrecio, select: lp.numero, distinct: true, order_by: lp.numero)
  end

  @doc "Todos los registros de una lista de precios."
  def list_por_numero(numero) do
    PsqlRepo.all(
      from lp in ListaPrecio,
        where: lp.numero == ^numero,
        order_by: lp.producto_codigo
    )
  end

  @doc "Mapa %{producto_codigo => precio} para una lista."
  def get_precios_map(numero) do
    PsqlRepo.all(
      from lp in ListaPrecio,
        where: lp.numero == ^numero,
        select: {lp.producto_codigo, lp.precio}
    )
    |> Map.new()
  end

  @doc "Obtiene un registro por lista + código de producto."
  def get(numero, producto_codigo) do
    PsqlRepo.get_by(ListaPrecio, numero: numero, producto_codigo: producto_codigo)
  end

  @doc "Upsert: crea o actualiza el precio de un producto en una lista."
  def upsert_precio(numero, producto_codigo, precio) do
    case get(numero, producto_codigo) do
      nil ->
        %ListaPrecio{}
        |> ListaPrecio.changeset(%{
            numero: numero,
            producto_codigo: producto_codigo,
            precio: precio
           })
        |> PsqlRepo.insert()

      existing ->
        existing
        |> ListaPrecio.changeset(%{precio: precio})
        |> PsqlRepo.update()
    end
  end

  @doc "Guarda un lote de precios para una lista. attrs = [%{producto_codigo, precio}]"
  def guardar_lista(numero, precios_list) do
    Enum.reduce(precios_list, {:ok, []}, fn %{"producto_codigo" => cod, "precio" => precio}, acc ->
      case acc do
        {:error, _} = err -> err
        {:ok, saved} ->
          precio_float = parse_precio(precio)
          case upsert_precio(numero, cod, precio_float) do
            {:ok, rec} -> {:ok, [rec | saved]}
            err        -> err
          end
      end
    end)
  end

  @doc "Elimina todos los registros de una lista."
  def eliminar_lista(numero) do
    PsqlRepo.delete_all(from lp in ListaPrecio, where: lp.numero == ^numero)
  end

  @doc "Elimina el precio de un producto en una lista."
  def eliminar_precio(numero, producto_codigo) do
    case get(numero, producto_codigo) do
      nil -> :ok
      rec -> PsqlRepo.delete(rec)
    end
  end

  defp parse_precio(v) when is_float(v), do: v
  defp parse_precio(v) when is_integer(v), do: v * 1.0
  defp parse_precio(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error  -> 0.0
    end
  end
  defp parse_precio(_), do: 0.0
end
