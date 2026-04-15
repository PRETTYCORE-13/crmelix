defmodule Prettycore.PsqlRepo.Migrations.AddBandaToSystemConfig do
  use Ecto.Migration

  def change do
    alter table(:system_config) do
      add :banda_texto, :string, default: "¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS"
      add :banda_color, :string, default: "#4f46e5"
    end
  end
end
