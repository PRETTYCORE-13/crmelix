defmodule Prettycore.PsqlRepo.Migrations.CreateMetaEndpoints do
  use Ecto.Migration

  def change do
    create table(:meta_endpoints, primary_key: false) do
      add :id,            :binary_id, primary_key: true
      add :meta_model_id, references(:meta_models, type: :binary_id, on_delete: :delete_all), null: false
      add :operacion,     :string, null: false
      add :activo,        :boolean, default: true, null: false
      add :requiere_auth, :boolean, default: true, null: false

      timestamps()
    end

    create index(:meta_endpoints, [:meta_model_id])
    create unique_index(:meta_endpoints, [:meta_model_id, :operacion])
  end
end
