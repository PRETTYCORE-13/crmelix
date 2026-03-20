defmodule Prettycore.Precios do
  @moduledoc """
  Obtiene y procesa precios de productos por cliente/dirección desde la API externa.
  Devuelve un mapa %{producto_codigo => precio} para consulta rápida.
  """

  alias Prettycore.Api.Client

  @doc """
  Retorna un mapa %{codigo_producto => precio_float} para el cliente/dirección indicados.
  Si la API falla o el usuario no tiene cliente asignado, retorna un mapa vacío.
  """
  def get_precios_map(cliente_codigo, dir_codigo)
      when is_binary(cliente_codigo) and cliente_codigo != "" do
    dir = if is_binary(dir_codigo) and dir_codigo != "", do: dir_codigo, else: "1"
    case Client.get_precios(cliente_codigo, dir) do
      {:ok, lista} when is_list(lista) ->
        Map.new(lista, fn item ->
          codigo = to_string(item["PRODUC_CODIGO_K"] || "")
          precio = item["VTAPRE_PRECIO"] || 0.0
          {codigo, precio}
        end)
      _ ->
        %{}
    end
  end

  def get_precios_map(_, _), do: %{}
end
