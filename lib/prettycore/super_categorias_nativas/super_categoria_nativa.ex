defmodule Prettycore.SuperCategoriasNativas.SuperCategoriaNativa do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "super_categorias_nativas" do
    field :nombre, :string
    field :activo, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(sc, attrs) do
    sc
    |> cast(attrs, [:nombre, :activo])
    |> validate_required([:nombre])
    |> validate_length(:nombre, min: 1, max: 100)
    |> unique_constraint(:nombre)
  end
end
