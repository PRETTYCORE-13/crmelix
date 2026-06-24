defmodule Prettycore.MonteAlban.MonteAlbanSchemaBagomSale do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [
    :id, :fecha_prev, :fecha_liq,
    :udn, :folio, :id_cliente, :sucursal,
    :id_producto, :nombre_producto, :ruta_prev, :ruta_rep,
    :cajas_prev, :cajas_liq,
    :monto_prev_bruto, :monto_liq_bruto,
    :monto_prev_neta, :monto_liq_neta,
    :inserted_at, :updated_at
  ]}

  schema "monte_alban_bagom_sales" do
    field :fecha_prev, :naive_datetime
    field :fecha_liq, :naive_datetime
    field :udn, :string
    field :folio, :integer
    field :id_cliente, :string
    field :sucursal, :integer
    field :id_producto, :string
    field :nombre_producto, :string
    field :ruta_prev, :string
    field :ruta_rep, :string
    field :cajas_prev, :decimal
    field :cajas_liq, :decimal
    field :monto_prev_bruto, :decimal
    field :monto_liq_bruto, :decimal
    field :monto_prev_neta, :decimal
    field :monto_liq_neta, :decimal

    timestamps()
  end

  def changeset(monte_alban_bagom_sales, attrs) do
    monte_alban_bagom_sales
    |> cast(attrs, [
      :fecha_prev, :fecha_liq,
      :udn, :folio, :id_cliente, :sucursal,
      :id_producto, :nombre_producto, :ruta_prev, :ruta_rep,
      :cajas_prev, :cajas_liq, :monto_prev_bruto, :monto_liq_bruto,
      :monto_prev_neta, :monto_liq_neta
    ])
    |> validate_required([:udn, :folio])
  end
end
