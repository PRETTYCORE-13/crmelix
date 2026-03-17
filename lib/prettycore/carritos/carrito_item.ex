defmodule Prettycore.Carritos.CarritoItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "carrito_items" do
    field :producto_codigo, :string
    field :cantidad, :integer, default: 1
    belongs_to :carrito, Prettycore.Carritos.Carrito
    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:carrito_id, :producto_codigo, :cantidad])
    |> validate_required([:carrito_id, :producto_codigo, :cantidad])
    |> validate_number(:cantidad, greater_than: 0)
    |> unique_constraint([:carrito_id, :producto_codigo])
  end
end
