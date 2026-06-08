defmodule PrettycoreWeb.ListaProductoPointController do
  use PrettycoreWeb, :controller

  alias Prettycore.Productos

  # GET /producto/point/lista
  # GET /producto/point/lista?q=BUSQUEDA
  # GET /producto/point/lista?categoria=NOMBRE

  def index(conn, %{"q" => q}) when is_binary(q) and q != "" do
    productos = Productos.search_productos(q)
    json(conn, %{ok: true, total: length(productos), data: Enum.map(productos, &format/1)})
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
end
