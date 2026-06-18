defmodule Prettycore.Catalogos.Listas.Lista do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :cliente_id, :activo, :inserted_at, :updated_at]}
  schema "listas" do
    field :nombre, :string
    field :activo, :boolean, default: true
    field      :cliente_id,  :integer
    has_many   :lista_items, Prettycore.Catalogos.Listas.ListaItem, foreign_key: :lista_id
    timestamps()
  end

  def changeset(lista, attrs) do
    lista
    |> cast(attrs, [:nombre, :activo, :cliente_id])
    |> validate_required([:nombre])
  end
end
