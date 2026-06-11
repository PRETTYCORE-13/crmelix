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

  defp get_modelo(modelo_nombre) do
    case Meta.obtener_modelo_por_nombre(modelo_nombre) do
      nil    -> :not_found
      modelo -> {:ok, modelo}
    end
  end

  defp not_found(conn, nombre),
    do: conn |> put_status(404) |> json(%{ok: false, error: "Modelo '#{nombre}' no existe"})

  defp run_query(sql, params) do
    Ecto.Adapters.SQL.query(PsqlRepo, sql, params)
  end

  defp rows_to_maps(columns, rows) do
    cols = Enum.map(columns, &String.to_atom/1)
    Enum.map(rows, fn row -> Enum.zip(cols, row) |> Map.new() end)
  end

  defp validate_payload(modelo, attrs) do
    columnas = Enum.sort_by(modelo.columnas, & &1.orden)
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

  # ── GET /api/dyn/:modelo  →  lista paginada ────────────────────

  def index(conn, %{"modelo" => modelo_nombre} = params) do
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        page   = String.to_integer(Map.get(params, "page",  "1"))
        limit  = String.to_integer(Map.get(params, "limit", "50"))
        offset = (page - 1) * limit
        sql       = "SELECT * FROM #{modelo.tabla_db} ORDER BY inserted_at DESC LIMIT $1 OFFSET $2"
        count_sql = "SELECT COUNT(*) FROM #{modelo.tabla_db}"
        with {:ok, res}   <- run_query(sql, [limit, offset]),
             {:ok, count} <- run_query(count_sql, []) do
          total = count.rows |> List.first() |> List.first()
          data  = rows_to_maps(res.columns, res.rows)
          json(conn, %{ok: true, modelo: modelo_nombre, total: total, page: page, limit: limit, data: data})
        else
          {:error, %{postgres: %{message: msg}}} -> json(conn |> put_status(500), %{ok: false, error: msg})
        end
    end
  end

  # ── GET /api/dyn/:modelo/:id  →  registro único ───────────────

  def show(conn, %{"modelo" => modelo_nombre, "id" => id}) do
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        sql = "SELECT * FROM #{modelo.tabla_db} WHERE id = $1 LIMIT 1"
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

  # ── POST /api/dyn/:modelo  →  crear ──────────────────────────

  def create(conn, %{"modelo" => modelo_nombre} = params) do
    attrs = Map.drop(params, ["modelo"])
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        case validate_payload(modelo, attrs) do
          {:error, errors} ->
            json(conn |> put_status(422), %{ok: false, errors: errors})
          :ok ->
            columnas     = Enum.sort_by(modelo.columnas, & &1.orden)
            campos       = Enum.map(columnas, & &1.nombre)
            valores      = Enum.map(campos, fn c -> Map.get(attrs, c) end)
            placeholders = campos |> Enum.with_index(1) |> Enum.map(fn {_, i} -> "$#{i}" end) |> Enum.join(", ")
            sql = "INSERT INTO #{modelo.tabla_db} (#{Enum.join(campos, ", ")}) VALUES (#{placeholders}) RETURNING *"
            case run_query(sql, valores) do
              {:ok, res} ->
                json(conn |> put_status(201), %{ok: true, data: rows_to_maps(res.columns, res.rows) |> List.first()})
              {:error, %{postgres: %{message: msg}}} ->
                json(conn |> put_status(500), %{ok: false, error: msg})
            end
        end
    end
  end

  # ── PUT /api/dyn/:modelo/:id  →  actualizar ───────────────────

  def update(conn, %{"modelo" => modelo_nombre, "id" => id} = params) do
    attrs = Map.drop(params, ["modelo", "id"])
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        fields = Map.keys(attrs)
        if fields == [] do
          json(conn |> put_status(422), %{ok: false, error: "Sin campos para actualizar"})
        else
          sets   = fields |> Enum.with_index(1) |> Enum.map(fn {f, i} -> "#{f} = $#{i}" end) |> Enum.join(", ")
          values = Enum.map(fields, &Map.get(attrs, &1))
          id_pos = length(fields) + 1
          sql = "UPDATE #{modelo.tabla_db} SET #{sets}, updated_at = NOW() WHERE id = $#{id_pos} RETURNING *"
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

  # ── DELETE /api/dyn/:modelo/:id  →  eliminar ─────────────────

  def delete(conn, %{"modelo" => modelo_nombre, "id" => id}) do
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        sql = "DELETE FROM #{modelo.tabla_db} WHERE id = $1 RETURNING id"
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

  # ── POST /api/dyn/:modelo/buscar  →  búsqueda por condiciones ─

  def buscar(conn, %{"modelo" => modelo_nombre} = params) do
    condiciones = Map.get(params, "condiciones", %{})
    case get_modelo(modelo_nombre) do
      :not_found -> not_found(conn, modelo_nombre)
      {:ok, modelo} ->
        if condiciones == %{} do
          sql = "SELECT * FROM #{modelo.tabla_db} ORDER BY inserted_at DESC"
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
          sql    = "SELECT * FROM #{modelo.tabla_db} WHERE #{where} ORDER BY inserted_at DESC"
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
