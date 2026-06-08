defmodule Prettycore.Productos.Producto do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:codigo, :string, autogenerate: false}

  schema "productos" do
    field :descripcion, :string
    field :desc_corta, :string
    field :marca, :string
    field :iva, :float, default: 0.0
    field :pzas_min_vta, :integer, default: 1
    field :activo, :boolean, default: true
    field :raw, :map
    field :imagen_url, :string

    many_to_many :categorias, Prettycore.Categorias.Categoria,
      join_through: "categoria_productos",
      join_keys: [producto_codigo: :codigo, categoria_id: :id]

    timestamps(type: :utc_datetime)
  end

def listar_productos_paginados(page \\ 1, per_page \\ 20) do
  Producto
  |> order_by([p], p.descripcion)
  |> Repo.paginate(page: page, page_size: per_page)
end
end
