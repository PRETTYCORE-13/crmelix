# lib/prettycore/catalogos/productos/productos_context.ex
defmodule Prettycore.Catalogos.Productos.ProductosContext do
  import Ecto.Query
  alias Prettycore.Repo
  alias Prettycore.Catalogos.Productos.{Producto, Categoria, Marca, Gama}

  # ========== PRODUCTOS ==========
  def listar_productos do
    Repo.all(Producto)
  end

  def listar_productos_activos do
    query = from p in Producto, where: p.activo == true
    Repo.all(query)
  end

  def obtener_producto(id) do
    Repo.get(Producto, id)
  end

  def buscar_por_codigo(codigo) do
    Repo.get_by(Producto, codigo: codigo)
  end

  def crear_producto(attrs) do
    %Producto{}
    |> Producto.changeset(attrs)
    |> Repo.insert()
  end

  def actualizar_producto(%Producto{} = producto, attrs) do
    producto
    |> Producto.changeset(attrs)
    |> Repo.update()
  end
end
