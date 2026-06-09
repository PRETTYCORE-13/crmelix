defmodule PrettycoreWeb.PtyController do
  use PrettycoreWeb, :controller

  alias Prettycore.PtyEcto

  # Mapa de nombre → módulo schema
  @schemas %{
    "productos"           => Prettycore.Productos.Producto,
    "categorias"          => Prettycore.Categorias.Categoria,
    "pedidos"             => Prettycore.Pedidos.Pedido,
    "pedido_items"        => Prettycore.Pedidos.PedidoItem,
    "usuarios"            => Prettycore.Auth.AuthUser,
    "carritos"            => Prettycore.Carritos.Carrito,
    "notificaciones"      => Prettycore.Notificaciones.Notificacion,
    "sucursales"          => Prettycore.Sucursales.Sucursal,
    "gamas"               => Prettycore.Gamas.Gama,
    "super_categorias"    => Prettycore.SuperCategorias.SuperCategoria,
  }

  # GET /pty/lista/:tabla?page=1&limit=50

  def index(conn, %{"tabla" => tabla} = params) do
    case Map.get(@schemas, tabla) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{ok: false, error: "Tabla '#{tabla}' no encontrada"})

      schema ->
        page   = params |> Map.get("page", "1")   |> parse_int(1)
        limit  = params |> Map.get("limit", "50")  |> parse_int(50)
        offset = (page - 1) * limit

        registros = PtyEcto.lista_schema(schema, offset, limit)
        total     = PtyEcto.count_tx(schema)

        json(conn, %{
          ok:      true,
          tabla:   tabla,
          total:   total,
          page:    page,
          limit:   limit,
          paginas: ceil(total / limit),
          data:    Enum.map(registros, &format/1)
        })
    end
  end

  # Convierte cualquier struct Ecto a mapa limpio
  defp format(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__, :inserted_at, :updated_at])
  end

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
