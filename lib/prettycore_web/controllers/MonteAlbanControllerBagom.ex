defmodule PrettycoreWeb.MonteAlbanControllerBagom do
  use PrettycoreWeb, :controller
  alias Prettycore.MonteAlban.MonteAlbanContext

  def index(conn, params) do
    page   = params |> Map.get("page",  "1")  |> parse_int(1)
    limit  = params |> Map.get("limit", "50") |> parse_int(50)
    offset = (page - 1) * limit

    total = MonteAlbanContext.count_listas()
    data  = MonteAlbanContext.listar_listas(offset, limit)

    json(conn, %{ok: true, total: total, page: page, limit: limit,
                 paginas: ceil(total / limit), data: data})
  end

  def create(conn, %{"registros" => registros}) when is_list(registros) do
    case MonteAlbanContext.insertar_ventas_bagom(registros) do
      {:ok, results} ->
        total = results |> Map.values() |> Enum.reduce(0, fn {count, _}, acc -> acc + count end)
        json(conn, %{ok: true, insertados: total})

      {:error, _op, _reason, _changes} ->
        conn |> put_status(422) |> json(%{ok: false, error: "Error al insertar registros"})
    end
  end

  def create(conn, _params) do
    conn |> put_status(400) |> json(%{ok: false, error: "Se esperan {\"registros\": [...]}"})
  end

  defp parse_int(val, default) do
    case Integer.parse(to_string(val)) do
      {n, _} when n > 0 -> n
      _                  -> default
    end
  end
end
