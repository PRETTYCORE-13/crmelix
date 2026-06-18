defmodule Prettycore.Catalogos.Listas.ListaProductos do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :cliente_id, :activo, :inserted_at, :updated_at]}
  schema "listas_productos" do
    field :nombre,     :string
    field :activo,     :boolean, default: true
    field :cliente_id, :integer
    has_many :items, Prettycore.Catalogos.Listas.ListaProductosItem, foreign_key: :lista_id
    timestamps()
  end

  def changeset(lista, attrs) do
    lista
    |> cast(attrs, [:nombre, :activo, :cliente_id])
    |> validate_required([:nombre])
  end
end
