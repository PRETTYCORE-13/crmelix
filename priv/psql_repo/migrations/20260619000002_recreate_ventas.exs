defmodule Prettycore.PsqlRepo.Migrations.RecreateVentas do
  use Ecto.Migration

  def change do
    drop table(:ventas)

    create table(:ventas) do
      add :fecha_prev,       :date
      add :fecha_liq,        :date
      add :udn,              :string
      add :folio,            :string
      add :id_cliente,       :string
      add :direccion,        :string
      add :id_producto,      :string
      add :nombre_producto,  :string
      add :ruta_prev,        :string
      add :ruta_rep,         :string
      add :cajas_prev,       :decimal, precision: 18, scale: 4
      add :cajas_liq,        :decimal, precision: 18, scale: 4
      add :monto_prev_bruto, :decimal, precision: 18, scale: 4
      add :monto_liq_bruto,  :decimal, precision: 18, scale: 4
      add :monto_prev_neta,  :decimal, precision: 18, scale: 4
      add :monto_liq_neta,   :decimal, precision: 18, scale: 4

      timestamps()
    end

    create index(:ventas, [:fecha_liq])
    create index(:ventas, [:id_cliente])
    create index(:ventas, [:id_producto])
  end
end
