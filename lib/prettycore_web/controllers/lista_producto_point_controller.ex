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
      data:     Enum.map(productos, &format/1) #Creamos MapaDeProductos
    })
  end

  defp format(MapaDeProductos) do
    %{
      codigo:      MapaDeProductos.codigo,
      descripcion: MapaDeProductos.descripcion,
      desc_corta:  MapaDeProductos.desc_corta,
      marca:       MapaDeProductos.marca,
      iva:         MapaDeProductos.iva,
      pzas_min:    MapaDeProductos.pzas_min_vta,
      activo:      MapaDeProductos.activo,
      imagen_url:  MapaDeProductos.imagen_url
    }
  end

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
