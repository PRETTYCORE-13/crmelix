defmodule Prettycore.Catalogos.Listas.ListaItem do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :lista_id, :producto_id, :inserted_at, :updated_at]}
  schema "lista_items" do
    field :lista_id,    :integer
    field :producto_id, :integer
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:lista_id, :producto_id])
    |> validate_required([:lista_id, :producto_id])
    |> unique_constraint([:lista_id, :producto_id])
  end
end
