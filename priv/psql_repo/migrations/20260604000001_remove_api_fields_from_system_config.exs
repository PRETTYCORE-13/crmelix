defmodule Prettycore.PsqlRepo.Migrations.RemoveApiFieldsFromSystemConfig do
  use Ecto.Migration

  def up do
    alter table(:system_config) do
      remove_if_exists :usuario, :string
      remove_if_exists :instancia, :string
      remove_if_exists :token, :string
      remove_if_exists :url, :string
      remove_if_exists :modo_nativo, :boolean
    end
  end

  def down do
    alter table(:system_config) do
      add :usuario, :string
      add :instancia, :string
      add :token, :string
      add :url, :string
      add :modo_nativo, :boolean, default: false
    end
  end
end
