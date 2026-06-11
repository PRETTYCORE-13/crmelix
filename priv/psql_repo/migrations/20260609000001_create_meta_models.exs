defmodule Prettycore.PsqlRepo.Migrations.CreateMetaModels do
  use Ecto.Migration

  def change do
    create table(:meta_models, primary_key: false) do
      add :id,          :binary_id, primary_key: true
      add :nombre,      :string, null: false
      add :descripcion, :string
      add :tabla_db,    :string, null: false
      add :activo,      :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:meta_models, [:nombre])
    create unique_index(:meta_models, [:tabla_db])
  end
end
