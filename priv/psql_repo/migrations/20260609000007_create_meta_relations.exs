defmodule Prettycore.PsqlRepo.Migrations.CreateMetaRelations do
  use Ecto.Migration

  def change do
    create table(:meta_relations, primary_key: false) do
      add :id,               :binary_id, primary_key: true
      add :meta_model_id,    references(:meta_models, type: :binary_id, on_delete: :delete_all), null: false
      add :contexto_destino_id, references(:meta_models, type: :binary_id, on_delete: :delete_all), null: false
      add :tipo,             :string, null: false  # belongs_to | has_many
      add :campo_fk,         :string, null: false  # nombre del campo FK en la tabla
      add :alias,            :string               # nombre legible de la relación

      timestamps()
    end

    create index(:meta_relations, [:meta_model_id])
    create index(:meta_relations, [:contexto_destino_id])
    create unique_index(:meta_relations, [:meta_model_id, :campo_fk])
  end
end
