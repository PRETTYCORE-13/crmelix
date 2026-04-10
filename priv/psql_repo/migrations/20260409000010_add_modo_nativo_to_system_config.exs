defmodule Prettycore.PsqlRepo.Migrations.AddModoNativoToSystemConfig do
  use Ecto.Migration

  def change do
    alter table(:system_config) do
      add :modo_nativo, :boolean, default: false, null: false
    end
  end
end
