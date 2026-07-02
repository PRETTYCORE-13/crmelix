defmodule PrettycoreWeb.VentaController do
  use PrettycoreWeb, :controller
  alias Prettycore.Apis.VentasContext

  def index(conn, params) do
    page   = params |> Map.get("page",  "1")  |> parse_int(1)
    limit  = params |> Map.get("limit", "500") |> parse_int(500)
    offset = (page - 1) * limit

    filtros = Map.take(params, ["fecha_desde", "fecha_hasta", "ctecli_codigo_k",
                                "produc_codigo_k", "vtarut_codigo_k"])

    total = VentasContext.count_ventas(filtros)
    data  = VentasContext.listar_ventas(offset, limit, filtros)

    json(conn, %{ok: true, tabla: "ventas", total: total, page: page,
                 limit: limit, paginas: ceil(total / limit), data: data})
  end

  def show(conn, %{"id" => id}) do
    case VentasContext.buscar_venta(id) do
      {:ok, venta}         -> json(conn, %{ok: true, data: venta})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{ok: false, error: "Venta no encontrada"})
    end
  end

  def create(conn, params) do
    case VentasContext.crear_venta(params) do
      {:ok, venta}        -> conn |> put_status(201) |> json(%{ok: true, data: venta})
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
