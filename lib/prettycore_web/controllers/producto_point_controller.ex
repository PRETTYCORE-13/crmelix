defmodule PrettycoreWeb.ProductoPointController do
  use PrettycoreWeb, :controller

  alias Prettycore.ApiTokens
  alias Prettycore.Productos

  # ── POST /producto/point/token ───────────────────────────────────────
  # Body: {"usuario": "...", "contrasena": "..."}
  # Retorna: {"ok": true, "token": "...", "tipo": "bearer"}

  def token(conn, %{"usuario" => usuario, "contrasena" => contrasena}) do
    case ApiTokens.autenticar_y_obtener_token(usuario, contrasena) do
      {:ok, api_token} ->
        json(conn, %{ok: true, token: api_token.token, tipo: "bearer"})

      {:error, :credenciales_invalidas} ->
        conn
        |> put_status(401)
        |> json(%{ok: false, error: "Credenciales inválidas o rol insuficiente"})
    end
  end

  def token(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{ok: false, error: "Se requieren los campos: usuario, contrasena"})
  end

  # ── GET /producto/point/sku?q=SKU ───────────────────────────────────
  # Busca productos por código (SKU)

def sku(conn, params) do
  # Extrae el código del body o de los params de URL (flexible)
  codigo = params["codigo"] || params["q"]

  cond do
    is_nil(codigo) or codigo == "" ->
      json(conn, %{ok: false, error: "Se requiere el parámetro: codigo o q"})

    true ->
      productos = Productos.search_by_sku(codigo)
      json(conn, %{ok: true, total: length(productos), data: Enum.map(productos, &format/1)})
  end
end

  # ── POST /producto/point/sku ─────────────────────────────────────────
  # Body: un producto o lista de productos
  # {"codigo": "SKU123", "descripcion": "...", "marca": "...", ...}

  def upsert_sku(conn, %{"productos" => lista}) when is_list(lista) do
    resultados = Enum.map(lista, &procesar_upsert/1)
    json(conn, %{ok: true, data: resultados})
  end

  def upsert_sku(conn, params) do
    json(conn, %{ok: true, data: [procesar_upsert(params)]})
  end

  # ── GET /producto/point/descrip?q=TEXTO ─────────────────────────────
  # Busca productos por descripción

  def descrip(conn, %{"q" => q}) when is_binary(q) and q != "" do
    productos = Productos.search_by_descrip(q)
    json(conn, %{ok: true, total: length(productos), data: Enum.map(productos, &format/1)})
  end

  # ── POST /producto/point/descrip ─────────────────────────────────────
  # Igual que upsert_sku — inserta/actualiza usando el mismo formato

  def upsert_descrip(conn, %{"productos" => lista}) when is_list(lista) do
    resultados = Enum.map(lista, &procesar_upsert/1)
    json(conn, %{ok: true, data: resultados})
  end

  def upsert_descrip(conn, params) do
    json(conn, %{ok: true, data: [procesar_upsert(params)]})
  end

  # Fallback para GET sin parámetro q
  def sku(conn, _), do: param_requerido(conn, "q")
  def descrip(conn, _), do: param_requerido(conn, "q")

  # ── Helpers privados ─────────────────────────────────────────────────

  defp procesar_upsert(attrs) do
    case Productos.upsert_producto(attrs) do
      {:ok, p} ->
        %{ok: true, codigo: p.codigo, descripcion: p.descripcion}

      {:error, changeset} ->
        errores =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Enum.reduce(opts, msg, fn {key, val}, acc ->
              String.replace(acc, "%{#{key}}", to_string(val))
            end)
          end)

        %{ok: false, codigo: Map.get(attrs, "codigo"), errores: errores}
    end
  end

  defp format(p) do
    %{
      codigo:      p.codigo,
      descripcion: p.descripcion,
      desc_corta:  p.desc_corta,
      marca:       p.marca,
      iva:         p.iva,
      pzas_min:    p.pzas_min_vta,
      activo:      p.activo,
      imagen_url:  p.imagen_url
    }
  end

  defp param_requerido(conn, param) do
    conn
    |> put_status(400)
    |> json(%{ok: false, error: "Se requiere el parámetro: #{param}"})
  end
end
