defmodule Prettycore.PsqlRepo.Migrations.CreateGamas do
  use Ecto.Migration

  def change do
    create table(:gamas, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :numero,          :integer, null: false
      add :nombre,          :string
      add :producto_codigo, :string,  null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gamas, [:numero, :producto_codigo])
    create index(:gamas, [:numero])
    create index(:gamas, [:producto_codigo])
  end
end
