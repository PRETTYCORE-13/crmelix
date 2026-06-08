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

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
