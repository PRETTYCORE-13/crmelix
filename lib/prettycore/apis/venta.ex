defmodule Prettycore.Apis.Venta do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "ventas" do
    field :fecha_prev,       :date
    field :fecha_liq,        :date
    field :udn,              :string
    field :folio,            :string
    field :id_cliente,       :string
    field :direccion,        :string
    field :id_producto,      :string
    field :nombre_producto,  :string
    field :ruta_prev,        :string
    field :ruta_rep,         :string
    field :cajas_prev,       :decimal
    field :cajas_liq,        :decimal
    field :monto_prev_bruto, :decimal
    field :monto_liq_bruto,  :decimal
    field :monto_prev_neta,  :decimal
    field :monto_liq_neta,   :decimal

    timestamps()
  end

  def changeset(venta, attrs) do
    venta
    |> cast(attrs, [
      :fecha_prev, :fecha_liq, :udn, :folio, :id_cliente, :direccion,
      :id_producto, :nombre_producto, :ruta_prev, :ruta_rep,
      :cajas_prev, :cajas_liq, :monto_prev_bruto, :monto_liq_bruto,
      :monto_prev_neta, :monto_liq_neta
    ])
  end
end
