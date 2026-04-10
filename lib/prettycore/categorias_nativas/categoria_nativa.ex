defmodule Prettycore.CategoriasNativas.CategoriaNativa do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "categorias_nativas" do
    field :nombre, :string
    field :activo, :boolean, default: true
    timestamps(type: :utc_datetime)
  end

  def changeset(cat, attrs) do
    cat
    |> cast(attrs, [:nombre, :activo])
    |> validate_required([:nombre])
    |> validate_length(:nombre, min: 1, max: 100)
    |> unique_constraint(:nombre)
  end
end
