defmodule Prettycore.PsqlRepo.Migrations.RenameListasToListasProductos do
  use Ecto.Migration

  def change do
    # Borrar las tablas con nombre incorrecto
    drop_if_exists table(:lista_items)
    drop_if_exists table(:listas)

    create_if_not_exists table(:listas_productos) do
      add :nombre,     :string, null: false
      add :activo,     :boolean, default: true, null: false
      add :cliente_id, :integer
      timestamps()
    end

    create_if_not_exists index(:listas_productos, [:cliente_id])

    create_if_not_exists table(:listas_productos_items) do
      add :lista_id,    :integer, null: false
      add :producto_id, :integer, null: false
      timestamps()
    end

    create_if_not_exists index(:listas_productos_items, [:lista_id])
    create_if_not_exists index(:listas_productos_items, [:producto_id])
    create_if_not_exists unique_index(:listas_productos_items, [:lista_id, :producto_id])
  end
end
