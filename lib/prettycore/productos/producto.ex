# lib/prettycore/productos/producto.ex (solo el esquema)
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

  def changeset(producto, attrs) do
    producto
    |> cast(attrs, [:codigo, :descripcion, :desc_corta, :marca, :iva, :pzas_min_vta, :activo, :raw, :imagen_url])
    |> validate_required([:codigo])
  end
end
