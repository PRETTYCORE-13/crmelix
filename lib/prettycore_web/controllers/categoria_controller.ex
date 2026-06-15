defmodule PrettycoreWeb.CategoriaController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.Categorias.CategoriasContext

  def index(conn, _params) do
    json(conn, %{ok: true, data: CategoriasContext.listar_categorias()})
  end

  def buscar_id(conn, %{"id" => id}) do
    case CategoriasContext.buscar_categoria(id) do
      {:ok, c}             -> json(conn, %{ok: true, data: c})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Categoría no encontrada"})
    end
  end

  def create(conn, params) do
    case CategoriasContext.crear_categoria(params) do
      {:ok, c}            -> conn |> put_status(201) |> json(%{ok: true, data: c})
      {:error, changeset} -> json(conn, %{ok: false, errors: changeset.errors})
    end
  end
end
