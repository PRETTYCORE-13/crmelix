# lib/prettycore_web/controllers/producto_controller.ex
defmodule PrettycoreWeb.ProductoController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.CatalogosContext  # ← Importante

  def index(conn, _params) do
    productos = CatalogosContext.listar_productos()
    json(conn, %{ok: true, data: productos})
  end

  def create(conn, params) do
    case CatalogosContext.crear_producto(params) do
      {:ok, producto} ->
        json(conn, %{ok: true, data: producto})
      {:error, changeset} ->
        json(conn, %{ok: false, errors: changeset.errors})
    end
  end
end
