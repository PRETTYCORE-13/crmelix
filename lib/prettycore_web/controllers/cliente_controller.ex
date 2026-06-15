defmodule PrettycoreWeb.ClienteController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.CatalogosContext

  def index(conn, _params) do
    clientes = CatalogosContext.listar_clientes()
    json(conn, %{ok: true, data: clientes})
  end

  def create(conn, params) do
    case CatalogosContext.crear_cliente(params) do
      {:ok, cliente}   -> json(conn, %{ok: true, data: cliente})
      {:error, changeset} -> json(conn, %{ok: false, errors: changeset.errors})
    end
  end

  def buscar_id(conn, %{"id" => id}) do
    case CatalogosContext.buscar_cliente(id) do
      {:ok, cliente}       -> json(conn, %{ok: true, data: cliente})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Cliente no encontrado"})
    end
  end
end
