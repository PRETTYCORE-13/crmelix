defmodule PrettycoreWeb.ClienteController do
  use PrettycoreWeb, :controller
  alias Prettycore.Catalogos.CatalogosContext

  def index(conn, params) do
    page   = params |> Map.get("page",  "1")  |> parse_int(1)
    limit  = params |> Map.get("limit", "50") |> parse_int(50)
    offset = (page - 1) * limit
    total  = CatalogosContext.count_clientes()
    data   = CatalogosContext.listar_clientes(offset, limit)

    json(conn, %{ok: true, tabla: "clientes", total: total, page: page,
                 limit: limit, paginas: ceil(total / limit), data: data})
  end

  def buscar_id(conn, %{"id" => id}) do
    case CatalogosContext.buscar_cliente(id) do
      {:ok, cliente}       -> json(conn, %{ok: true, data: cliente})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Cliente no encontrado"})
    end
  end

  def create(conn, params) do
    case CatalogosContext.crear_cliente(params) do
      {:ok, cliente}      -> conn |> put_status(201) |> json(%{ok: true, data: cliente})
      {:error, changeset} -> json(conn, %{ok: false, errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case CatalogosContext.buscar_cliente(id) do
      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{ok: false, error: "Cliente no encontrado"})
      {:ok, cliente} ->
        case CatalogosContext.actualizar_cliente(cliente, params) do
          {:ok, actualizado}  -> json(conn, %{ok: true, data: actualizado})
          {:error, changeset} -> conn |> put_status(422) |> json(%{ok: false, errors: format_errors(changeset)})
        end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc -> String.replace(acc, "%{#{k}}", to_string(v)) end)
    end)
  end

  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} when n > 0 -> n
      _                  -> default
    end
  end
end
