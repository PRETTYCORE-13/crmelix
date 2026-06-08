# lib/prettycore/productos/productos_context.ex (nuevo archivo)
defmodule Prettycore.Productos.ProductosContext do
  import Ecto.Query
  alias Prettycore.Repo
  alias Prettycore.Productos.Producto

  def listar_productos_paginados(page \\ 1, per_page \\ 20) do
    Producto
    |> order_by([p], p.descripcion)
    |> Repo.paginate(page: page, page_size: per_page)
  end
end
