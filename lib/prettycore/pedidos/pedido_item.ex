defmodule Prettycore.Pedidos.PedidoItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pedido_items" do
    field :producto_codigo, :string
    field :descripcion, :string
    field :cantidad, :integer, default: 1
    field :precio_unitario, :float, default: 0.0
    belongs_to :pedido, Prettycore.Pedidos.Pedido
    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:pedido_id, :producto_codigo, :descripcion, :cantidad, :precio_unitario])
    |> validate_required([:pedido_id, :producto_codigo, :cantidad])
    |> validate_number(:cantidad, greater_than: 0)
  end
end
