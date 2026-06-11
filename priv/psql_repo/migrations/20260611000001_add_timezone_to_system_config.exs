defmodule Prettycore.PsqlRepo.Migrations.AddTimezoneToSystemConfig do
  use Ecto.Migration

  def change do
    alter table(:system_config) do
      add :timezone, :string, default: "America/Mexico_City"
    end
  end
end
