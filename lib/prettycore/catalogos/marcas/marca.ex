defmodule Prettycore.Catalogos.Marcas.Marca do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :activo, :inserted_at, :updated_at]}

  schema "marcas" do
    field :nombre, :string
    field :activo, :boolean, default: true
    timestamps()
  end

  def changeset(marca, attrs) do
    marca
    |> cast(attrs, [:nombre, :activo])
    |> validate_required([:nombre])
    |> unique_constraint(:nombre)
  end
end
