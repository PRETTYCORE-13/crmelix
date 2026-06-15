defmodule PrettycoreWeb.SupercategoriaController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.Supercategorias.SupercategoriasContext

  def index(conn, _params) do
    json(conn, %{ok: true, data: SupercategoriasContext.listar_supercategorias()})
  end

  def buscar_id(conn, %{"id" => id}) do
    case SupercategoriasContext.buscar_supercategoria(id) do
      {:ok, s}             -> json(conn, %{ok: true, data: s})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Supercategoría no encontrada"})
    end
  end

  def create(conn, params) do
    case SupercategoriasContext.crear_supercategoria(params) do
      {:ok, s}            -> conn |> put_status(201) |> json(%{ok: true, data: s})
      {:error, changeset} -> json(conn, %{ok: false, errors: changeset.errors})
    end
  end
end
