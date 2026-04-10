defmodule Prettycore.StockSucursal.StockItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "stock_sucursal" do
    field :producto_codigo, :string
    field :sucursal_numero, :integer
    field :cantidad, :integer, default: 0
    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:producto_codigo, :sucursal_numero, :cantidad])
    |> validate_required([:producto_codigo, :sucursal_numero, :cantidad])
    |> validate_number(:cantidad, greater_than_or_equal_to: 0)
    |> unique_constraint([:producto_codigo, :sucursal_numero],
         name: :stock_sucursal_producto_codigo_sucursal_numero_index)
  end
end
