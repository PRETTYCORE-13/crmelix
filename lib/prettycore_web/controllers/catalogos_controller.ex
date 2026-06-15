# lib/prettycore_web/controllers/catalogos_controller.ex
defmodule PrettycoreWeb.CatalogosController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.CatalogosContext

  # Productos
  def index_productos(conn, _params) do
    productos = CatalogosContext.listar_productos_activos()
    json(conn, %{ok: true, data: productos})
  end

  def show_producto(conn, %{"id" => id}) do
    case CatalogosContext.obtener_producto(id) do
      nil -> json_error(conn, 404, "Producto no encontrado")
      producto -> json(conn, %{ok: true, data: producto})
    end
  end

  # Clientes
  def index_clientes(conn, _params) do
    clientes = CatalogosContext.listar_clientes_activos()
    json(conn, %{ok: true, data: clientes})
  end

  def show_cliente(conn, %{"id" => id}) do
    case CatalogosContext.obtener_cliente(id) do
      nil -> json_error(conn, 404, "Cliente no encontrado")
      cliente -> json(conn, %{ok: true, data: cliente})
    end
  end

  defp json_error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{ok: false, error: message})
  end
end
