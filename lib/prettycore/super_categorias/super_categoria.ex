defmodule Prettycore.SuperCategorias.SuperCategoria do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "super_categorias" do
    field :nombre, :string
    field :descripcion, :string
    field :imagen_url, :string
    field :orden, :integer, default: 0

    many_to_many :productos, Prettycore.Productos.Producto,
      join_through: "super_categoria_productos",
      join_keys: [super_categoria_id: :id, producto_codigo: :codigo],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(sc, attrs) do
    sc
    |> cast(attrs, [:nombre, :descripcion, :imagen_url, :orden])
    |> validate_required([:nombre])
    |> unique_constraint(:nombre)
  end
end
