defmodule Prettycore.PsqlRepo.Migrations.CreateClienteNativoGamas do
  use Ecto.Migration

  def change do
    create table(:cliente_nativo_gamas, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :cliente_nativo_id, references(:clientes_nativos, type: :binary_id, on_delete: :delete_all), null: false
      add :gama_numero, :integer, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:cliente_nativo_gamas, [:cliente_nativo_id, :gama_numero])
    create index(:cliente_nativo_gamas, [:cliente_nativo_id])
  end
end
