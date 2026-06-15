defmodule PrettycoreWeb.MarcaController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.Marcas.MarcasContext

  def index(conn, _params) do
    json(conn, %{ok: true, data: MarcasContext.listar_marcas()})
  end

  def buscar_id(conn, %{"id" => id}) do
    case MarcasContext.buscar_marca(id) do
      {:ok, marca}         -> json(conn, %{ok: true, data: marca})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Marca no encontrada"})
    end
  end

  def create(conn, params) do
    case MarcasContext.crear_marca(params) do
      {:ok, marca}        -> conn |> put_status(201) |> json(%{ok: true, data: marca})
      {:error, changeset} -> json(conn, %{ok: false, errors: changeset.errors})
    end
  end
end
