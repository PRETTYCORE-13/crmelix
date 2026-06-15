defmodule Prettycore.Catalogos.Categorias.Categoria do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :supercategoria_id, :activo, :inserted_at, :updated_at]}

  schema "categorias" do
    field :nombre, :string
    field :activo, :boolean, default: true
    belongs_to :supercategoria, Prettycore.Catalogos.Supercategorias.Supercategoria
    timestamps()
  end

  def changeset(categoria, attrs) do
    categoria
    |> cast(attrs, [:nombre, :activo, :supercategoria_id])
    |> validate_required([:nombre])
    |> unique_constraint(:nombre)
  end
end
