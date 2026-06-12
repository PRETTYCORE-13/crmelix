defmodule PrettycoreWeb.DynController do
  use PrettycoreWeb, :controller

  alias Prettycore.Meta
  alias Prettycore.PsqlRepo
  alias Prettycore.ApiTokens

  # ── POST /api/auth/token  →  obtener Bearer token ────────────

  def auth_token(conn, %{"usuario" => usuario, "contrasena" => contrasena}) do
    case ApiTokens.autenticar_y_obtener_token(usuario, contrasena) do
      {:ok, token} ->
        json(conn, %{ok: true, token: token.token})
      {:error, _} ->
        json(conn |> put_status(401), %{ok: false, error: "Credenciales inválidas"})
    end
  end

  def auth_token(conn, _) do
    json(conn |> put_status(422), %{ok: false, error: "Requiere usuario y contrasena"})
  end

  # ── Helpers ───────────────────────────────────────────────────

  defp get_contexto(contexto_nombre) do
    case Meta.obtener_contexto_por_nombre(contexto_nombre) do
      nil      -> :not_found
      contexto -> {:ok, contexto}
    end
  end

  defp not_found(conn, nombre),
    do: conn |> put_status(404) |> json(%{ok: false, error: "contexto '#{nombre}' no existe"})

  defp run_query(sql, params) do
    Ecto.Adapters.SQL.query(PsqlRepo, sql, params)
  end

  defp rows_to_maps(columns, rows) do
    cols = Enum.map(columns, &String.to_atom/1)
    Enum.map(rows, fn row ->
      row |> Enum.map(&encode_value/1) |> then(&Enum.zip(cols, &1)) |> Map.new()
    end)
  end

  defp encode_value(v) when is_binary(v) do
    if String.valid?(v) do
      v
    else
      case byte_size(v) do
        16 -> Ecto.UUID.load!(v)
        _  -> Base.encode64(v)
      end
    end
  end

  defp encode_value(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp encode_value(%DateTime{} = dt),      do: DateTime.to_iso8601(dt)
  defp encode_value(%Date{} = d),           do: Date.to_iso8601(d)
  defp encode_value(%Decimal{} = d),        do: Decimal.to_string(d)
  defp encode_value(v),                     do: v

  defp validate_payload(contexto, attrs) do
    columnas = Enum.sort_by(contexto.columnas, & &1.orden)
    errors =
      Enum.flat_map(columnas, fn col ->
        val = Map.get(attrs, col.nombre) || Map.get(attrs, String.to_atom(col.nombre))
        cond do
          col.requerido && (is_nil(val) || val == "") ->
            ["#{col.etiqueta || col.nombre} es requerido"]
          col.min_longitud && is_binary(val) && String.length(val) < col.min_longitud ->
            ["#{col.etiqueta || col.nombre} debe tener al menos #{col.min_longitud} caracteres"]
          col.max_longitud && is_binary(val) && String.length(val) > col.max_longitud ->
            ["#{col.etiqueta || col.nombre} no puede superar #{col.max_longitud} caracteres"]
          true ->
            []
        end
      end)
    if errors == [], do: :ok, else: {:error, errors}
  end

  # ── GET /api/dyn/:contexto  →  lista paginada ────────────────────

  def index(conn, %{"contexto" => contexto_nombre} = params) do
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        page   = String.to_integer(Map.get(params, "page",  "1"))
        limit  = String.to_integer(Map.get(params, "limit", "50"))
        offset = (page - 1) * limit
        sql       = "SELECT * FROM #{contexto.tabla_db} ORDER BY inserted_at DESC LIMIT $1 OFFSET $2"
        count_sql = "SELECT COUNT(*) FROM #{contexto.tabla_db}"
        with {:ok, res}   <- run_query(sql, [limit, offset]),
             {:ok, count} <- run_query(count_sql, []) do
          total = count.rows |> List.first() |> List.first()
          data  = rows_to_maps(res.columns, res.rows)
          json(conn, %{ok: true, contexto: contexto_nombre, total: total, page: page, limit: limit, data: data})
        else
          {:error, %{postgres: %{message: msg}}} -> json(conn |> put_status(500), %{ok: false, error: msg})
        end
    end
  end

  # ── GET /api/dyn/:contexto/:id  →  registro único ───────────────

  def show(conn, %{"contexto" => contexto_nombre, "id" => id}) do
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        sql = "SELECT * FROM #{contexto.tabla_db} WHERE id = $1 LIMIT 1"
        case run_query(sql, [id]) do
          {:ok, %{rows: []}} ->
            json(conn |> put_status(404), %{ok: false, error: "Registro no encontrado"})
          {:ok, res} ->
            [row] = res.rows
            json(conn, %{ok: true, data: rows_to_maps(res.columns, [row]) |> List.first()})
          {:error, %{postgres: %{message: msg}}} ->
            json(conn |> put_status(500), %{ok: false, error: msg})
        end
    end
  end

  # ── POST /api/dyn/:contexto  →  crear ──────────────────────────

  def create(conn, %{"contexto" => contexto_nombre} = params) do
    attrs = Map.drop(params, ["contexto"])
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        case validate_payload(contexto, attrs) do
          {:error, errors} ->
            json(conn |> put_status(422), %{ok: false, errors: errors})
          :ok ->
            columnas     = Enum.sort_by(contexto.columnas, & &1.orden)
            campos       = Enum.map(columnas, & &1.nombre)
            valores      = Enum.map(campos, fn c -> Map.get(attrs, c) end)
            placeholders = campos |> Enum.with_index(1) |> Enum.map(fn {_, i} -> "$#{i}" end) |> Enum.join(", ")
            sql = "INSERT INTO #{contexto.tabla_db} (#{Enum.join(campos, ", ")}) VALUES (#{placeholders}) RETURNING *"
            case run_query(sql, valores) do
              {:ok, res} ->
                json(conn |> put_status(201), %{ok: true, data: rows_to_maps(res.columns, res.rows) |> List.first()})
              {:error, %{postgres: %{message: msg}}} ->
                json(conn |> put_status(500), %{ok: false, error: msg})
            end
        end
    end
  end

  # ── PUT /api/dyn/:contexto/:id  →  actualizar ───────────────────

  def update(conn, %{"contexto" => contexto_nombre, "id" => id} = params) do
    attrs = Map.drop(params, ["contexto", "id"])
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        fields = Map.keys(attrs)
        if fields == [] do
          json(conn |> put_status(422), %{ok: false, error: "Sin campos para actualizar"})
        else
          sets   = fields |> Enum.with_index(1) |> Enum.map(fn {f, i} -> "#{f} = $#{i}" end) |> Enum.join(", ")
          values = Enum.map(fields, &Map.get(attrs, &1))
          id_pos = length(fields) + 1
          sql = "UPDATE #{contexto.tabla_db} SET #{sets}, updated_at = NOW() WHERE id = $#{id_pos} RETURNING *"
          case run_query(sql, values ++ [id]) do
            {:ok, %{rows: []}} ->
              json(conn |> put_status(404), %{ok: false, error: "Registro no encontrado"})
            {:ok, res} ->
              json(conn, %{ok: true, data: rows_to_maps(res.columns, res.rows) |> List.first()})
            {:error, %{postgres: %{message: msg}}} ->
              json(conn |> put_status(500), %{ok: false, error: msg})
          end
        end
    end
  end

  # ── DELETE /api/dyn/:contexto/:id  →  eliminar ─────────────────

  def delete(conn, %{"contexto" => contexto_nombre, "id" => id}) do
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        sql = "DELETE FROM #{contexto.tabla_db} WHERE id = $1 RETURNING id"
        case run_query(sql, [id]) do
          {:ok, %{rows: []}} ->
            json(conn |> put_status(404), %{ok: false, error: "Registro no encontrado"})
          {:ok, _} ->
            json(conn, %{ok: true, id: id})
          {:error, %{postgres: %{message: msg}}} ->
            json(conn |> put_status(500), %{ok: false, error: msg})
        end
    end
  end

  # ── POST /api/dyn/:contexto/buscar  →  búsqueda por condiciones ─

  def buscar(conn, %{"contexto" => contexto_nombre} = params) do
    condiciones = Map.get(params, "condiciones", %{})
    case get_contexto(contexto_nombre) do
      :not_found -> not_found(conn, contexto_nombre)
      {:ok, contexto} ->
        if condiciones == %{} do
          sql = "SELECT * FROM #{contexto.tabla_db} ORDER BY inserted_at DESC"
          case run_query(sql, []) do
            {:ok, res} ->
              data = rows_to_maps(res.columns, res.rows)
              json(conn, %{ok: true, total: length(data), data: data})
            {:error, %{postgres: %{message: msg}}} ->
              json(conn |> put_status(500), %{ok: false, error: msg})
          end
        else
          fields = Map.keys(condiciones)
          where  = fields |> Enum.with_index(1) |> Enum.map(fn {f, i} -> "#{f} = $#{i}" end) |> Enum.join(" AND ")
          values = Enum.map(fields, &Map.get(condiciones, &1))
          sql    = "SELECT * FROM #{contexto.tabla_db} WHERE #{where} ORDER BY inserted_at DESC"
          case run_query(sql, values) do
            {:ok, res} ->
              data = rows_to_maps(res.columns, res.rows)
              json(conn, %{ok: true, total: length(data), data: data})
            {:error, %{postgres: %{message: msg}}} ->
              json(conn |> put_status(500), %{ok: false, error: msg})
          end
        end
    end
  end
end
