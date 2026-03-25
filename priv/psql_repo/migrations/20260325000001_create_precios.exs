defmodule Prettycore.Repo.Migrations.CreatePrecios do
  use Ecto.Migration

  def change do
    create table(:precios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :producto_codigo, :string, null: false
      add :precio, :float, null: false
      add :cliente_codigo, :string, null: false
      add :dir_codigo, :string, null: false
      add :lista_precio, :integer
      add :unidad, :string
      timestamps()
    end

    create unique_index(:precios, [:cliente_codigo, :dir_codigo, :producto_codigo])
    create index(:precios, [:cliente_codigo, :dir_codigo])
  end
end
