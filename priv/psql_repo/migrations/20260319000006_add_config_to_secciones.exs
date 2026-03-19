defmodule Prettycore.PsqlRepo.Migrations.AddConfigToSecciones do
  use Ecto.Migration

  def change do
    alter table(:secciones) do
      add :config, :map, default: %{}
    end
  end
end
