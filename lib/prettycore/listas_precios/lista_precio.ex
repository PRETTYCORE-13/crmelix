defmodule Prettycore.ListasPrecios.ListaPrecio do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "listas_precios" do
    field :numero,          :integer
    field :producto_codigo, :string
    field :precio,          :float,  default: 0.0
    field :descripcion,     :string

    timestamps(type: :utc_datetime)
  end

  def changeset(lp, attrs) do
    lp
    |> cast(attrs, [:numero, :producto_codigo, :precio, :descripcion])
    |> validate_required([:numero, :producto_codigo, :precio])
    |> validate_number(:numero, greater_than: 0)
    |> validate_number(:precio, greater_than_or_equal_to: 0)
    |> unique_constraint([:numero, :producto_codigo],
        name: :listas_precios_numero_producto_codigo_index,
        message: "ya existe un precio para este producto en esa lista")
  end
end
