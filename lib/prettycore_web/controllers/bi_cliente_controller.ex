defmodule PrettycoreWeb.BIClienteController do
  use PrettycoreWeb, :controller
  alias Prettycore.BI.ClientesContext

  def index(conn, params) do
    page   = params |> Map.get("page",  "1")   |> parse_int(1)
    limit  = params |> Map.get("limit", "500") |> parse_int(500)
    offset = (page - 1) * limit

    filtros = Map.take(params, ["id_cliente", "udn", "nombre_comercial", "preventa", "reparto"])

    total = ClientesContext.count_clientes(filtros)
    data  = ClientesContext.listar_clientes(offset, limit, filtros)

    json(conn, %{ok: true, tabla: "bi_clientes", total: total, page: page,
                 limit: limit, paginas: ceil(total / limit), data: data})
  end

  def show(conn, %{"id" => id}) do
    case ClientesContext.buscar_cliente(id) do
      {:ok, cliente}       -> json(conn, %{ok: true, data: cliente})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Cliente no encontrado"})
    end
  end

  def create(conn, params) do
    case ClientesContext.crear_cliente(params) do
      {:ok, cliente}      -> conn |> put_status(201) |> json(%{ok: true, data: cliente})
      {:error, changeset} -> conn |> put_status(422) |> json(%{ok: false, errors: format_errors(changeset)})
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
