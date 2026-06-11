defmodule Prettycore.PsqlRepo.Migrations.AddTablaCreateToMetaModels do
  use Ecto.Migration

  def change do
    alter table(:meta_models) do
      add :tabla_creada, :boolean, default: false, null: false
    end
  end
end
