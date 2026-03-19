defmodule Prettycore.SuperCategorias do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.SuperCategorias.SuperCategoria

  def list_super_categorias do
    Repo.all(from sc in SuperCategoria, order_by: [asc: sc.orden, asc: sc.nombre])
  end

  def get_super_categoria_con_productos(id) do
    case Repo.get(SuperCategoria, id) do
      nil -> nil
      sc  -> Repo.preload(sc, :productos)
    end
  end

  def create_super_categoria(attrs) do
    %SuperCategoria{} |> SuperCategoria.changeset(attrs) |> Repo.insert()
  end

  def update_super_categoria(%SuperCategoria{} = sc, attrs) do
    sc |> SuperCategoria.changeset(attrs) |> Repo.update()
  end

  def delete_super_categoria(%SuperCategoria{} = sc), do: Repo.delete(sc)

  def set_productos(%SuperCategoria{} = sc, codigos) when is_list(codigos) do
    productos = Repo.all(from p in Prettycore.Productos.Producto, where: p.codigo in ^codigos)
    sc
    |> Repo.preload(:productos)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:productos, productos)
    |> Repo.update()
  end
end
