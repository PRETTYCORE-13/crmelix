defmodule Prettycore.PsqlRepo.Migrations.CreateStockSucursal do
  use Ecto.Migration

  def change do
    create table(:stock_sucursal, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :producto_codigo, references(:productos_nativos, column: :codigo, type: :string, on_delete: :delete_all), null: false
      add :sucursal_numero, :integer, null: false
      add :cantidad, :integer, default: 0, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:stock_sucursal, [:producto_codigo, :sucursal_numero])
  end
end
