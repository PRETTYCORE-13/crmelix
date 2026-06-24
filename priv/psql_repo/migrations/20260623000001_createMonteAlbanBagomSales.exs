defmodule YourApp.Repo.Migrations.MonteAlbanBagomSales do
  use Ecto.Migration

  def change do
    create table(:monte_alban_bagom_sales) do
      # Fechas (sin zona horaria, puedes cambiar a :utc_datetime si prefieres)
      add :fecha_prev, :naive_datetime
      add :fecha_liq, :naive_datetime

      # Campos según el Excel
      add :udn, :string, size: 6
      add :folio, :integer
      add :id_cliente, :string, size: 10
      add :sucursal, :integer
      add :id_producto, :string, size: 20
      add :nombre_producto, :string, size: 100
      add :ruta_prev, :string, size: 60
      add :ruta_rep, :string, size: 60

      # Decimales con precisión 20 y escala 4
      add :cajas_prev, :decimal, precision: 20, scale: 4
      add :cajas_liq, :decimal, precision: 20, scale: 4
      add :monto_prev_bruto, :decimal, precision: 20, scale: 4
      add :monto_liq_bruto, :decimal, precision: 20, scale: 4
      add :monto_prev_neta, :decimal, precision: 20, scale: 4
      add :monto_liq_neta, :decimal, precision: 20, scale: 4

      # Timestamps estándar de Ecto (opcional, pero recomendado)
      timestamps()
    end

    # Índices opcionales (puedes agregar los que uses en consultas)
    create index(:monte_alban_bagom_sales, [:udn])
    create index(:monte_alban_bagom_sales, [:folio])
    create index(:monte_alban_bagom_sales, [:id_cliente])
    create index(:monte_alban_bagom_sales, [:sucursal])
  end
end
