defmodule Prettycore.Sucursales.Sucursal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "sucursales" do
    field :numero, :integer
    field :nombre, :string
    field :direccion, :string
    field :activo, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(sucursal, attrs) do
    sucursal
    |> cast(attrs, [:numero, :nombre, :direccion, :activo])
    |> validate_required([:numero, :nombre])
    |> validate_number(:numero, greater_than: 0)
    |> unique_constraint(:numero)
  end
end
