defmodule PrettycoreWeb.ListaProductoPointController do
  use PrettycoreWeb, :controller

  alias Prettycore.Productos

  # GET /producto/point/lista
  # GET /producto/point/lista?page=2&limit=50

  def index(conn, params) do
    page  = params |> Map.get("page", "1")  |> parse_int(1)
    limit = params |> Map.get("limit", "50") |> parse_int(50)
    offset = (page - 1) * limit

    productos = Productos.lista_schema(Productos, offset, limit)
    total     = Productos.count_tx(Productos, :count)

IO.inspect(%{page: page, limit: limit, offset: offset, total: total}, label: "DEBUG")

    json(conn, %{
      ok:       true,
      total:    total,
      page:     page,
      limit:    limit,
      paginas:  ceil(total / limit),
      data:     Enum.map(productos, &format/1) #Creamos MapaDeProductos
    })
  end

  defp format(mapa_de_productos) do
    %{
      codigo:      mapa_de_productos.codigo,
      descripcion: mapa_de_productos.descripcion,
      desc_corta:  mapa_de_productos.desc_corta,
      marca:       mapa_de_productos.marca,
      iva:         mapa_de_productos.iva,
      pzas_min:    mapa_de_productos.pzas_min_vta,
      activo:      mapa_de_productos.activo,
      imagen_url:  mapa_de_productos.imagen_url
    }
  end

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {n, _} when n > 0 -> n
      _ -> default
    end
  end
end
