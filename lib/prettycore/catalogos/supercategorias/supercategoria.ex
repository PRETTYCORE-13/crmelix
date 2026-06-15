defmodule Prettycore.Catalogos.Supercategorias.Supercategoria do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :activo, :inserted_at, :updated_at]}

  schema "supercategorias" do
    field :nombre, :string
    field :activo, :boolean, default: true
    timestamps()
  end

  def changeset(supercategoria, attrs) do
    supercategoria
    |> cast(attrs, [:nombre, :activo])
    |> validate_required([:nombre])
    |> unique_constraint(:nombre)
  end
end
