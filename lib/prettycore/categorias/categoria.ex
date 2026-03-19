defmodule Prettycore.Categorias.Categoria do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categorias" do
    field :nombre, :string
    field :imagen_url, :string
    field :orden, :integer, default: 0

    many_to_many :productos, Prettycore.Productos.Producto,
      join_through: "categoria_productos",
      join_keys: [categoria_id: :id, producto_codigo: :codigo],
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  def changeset(categoria, attrs) do
    categoria
    |> cast(attrs, [:nombre, :imagen_url, :orden])
    |> validate_required([:nombre])
    |> unique_constraint(:nombre)
  end
end
