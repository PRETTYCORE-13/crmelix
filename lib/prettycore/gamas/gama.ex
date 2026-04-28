defmodule Prettycore.Gamas.Gama do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "gamas" do
    field :numero,          :integer
    field :nombre,          :string
    field :producto_codigo, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(gama, attrs) do
    gama
    |> cast(attrs, [:numero, :nombre, :producto_codigo])
    |> validate_required([:numero, :producto_codigo])
    |> validate_number(:numero, greater_than: 0)
    |> unique_constraint([:numero, :producto_codigo],
        name: :gamas_numero_producto_codigo_index,
        message: "ese producto ya está en esta gama")
  end
end
