defmodule PrettycoreWeb.ListaProductoPointController do
  use PrettycoreWeb, :controller

  alias Prettycore.Productos

  # GET /producto/point/lista
  # GET /producto/point/lista?page=2&limit=50

  def index(conn, params) do
    page  = params |> Map.get("page", "1")  |> parse_int(1)
    limit = params |> Map.get("limit", "50") |> parse_int(50)
    offset = (page - 1) * limit

    productos = Productos.list_productos_paginado(offset, limit)
    total     = Productos.count_productos()

    json(conn, %{
      ok:       true,
      total:    total,
      page:     page,
      limit:    limit,
      paginas:  ceil(total / limit),
      data:     Enum.map(productos, &format/1)
    })
  end

  defp format(x) do
    %{
      codigo:      x.codigo,
      descripcion: x.descripcion,
      desc_corta:  x.desc_corta,
      marca:       x.marca,
      iva:         x.iva,
      pzas_min:    x.pzas_min_vta,
      activo:      x.activo,
      imagen_url:  x.imagen_url
    }
  end

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
