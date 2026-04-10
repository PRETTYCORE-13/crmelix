defmodule Prettycore.PsqlRepo.Migrations.CreateListasPrecios do
  use Ecto.Migration

  def change do
    create table(:listas_precios, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :numero,          :integer, null: false
      add :producto_codigo, :string,  null: false
      add :precio,          :float,   null: false, default: 0.0
      add :descripcion,     :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:listas_precios, [:numero, :producto_codigo])
    create index(:listas_precios, [:numero])
    create index(:listas_precios, [:producto_codigo])
  end
end
