defmodule Prettycore.Categorias do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Categorias.Categoria

  @defaults [
    "Todos", "Refrescos", "Aguas", "Lácteos", "Botanas",
    "Dulces", "Jugos", "Energéticas", "Deportivas", "Cervezas",
    "Licores", "Limpieza"
  ]

  def list_categorias do
    cats = Repo.all(from c in Categoria, order_by: [asc: c.orden, asc: c.nombre])
    if Enum.empty?(cats), do: seed_defaults(), else: cats
  end

  def seed_defaults do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    @defaults
    |> Enum.with_index()
    |> Enum.map(fn {nombre, i} ->
      %Categoria{}
      |> Categoria.changeset(%{nombre: nombre, orden: i})
      |> Repo.insert(on_conflict: :nothing)
    end)
    Repo.all(from c in Categoria, order_by: [asc: c.orden, asc: c.nombre])
  end

  def create_categoria(attrs) do
    %Categoria{} |> Categoria.changeset(attrs) |> Repo.insert()
  end

  def update_categoria(%Categoria{} = cat, attrs) do
    cat |> Categoria.changeset(attrs) |> Repo.update()
  end

  def delete_categoria(%Categoria{} = cat), do: Repo.delete(cat)

  @doc "Obtiene una categoría con sus productos precargados."
  def get_categoria_con_productos(id) do
    case Repo.get(Categoria, id) do
      nil -> nil
      cat -> Repo.preload(cat, :productos)
    end
  end

  @doc "Reemplaza los productos asignados a una categoría."
  def set_productos(%Categoria{} = cat, codigos) when is_list(codigos) do
    productos = Repo.all(from p in Prettycore.Productos.Producto, where: p.codigo in ^codigos)
    cat
    |> Repo.preload(:productos)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:productos, productos)
    |> Repo.update()
  end
end
