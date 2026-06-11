defmodule Prettycore.PsqlRepo.Migrations.CreateMetaColumns do
  use Ecto.Migration

  def change do
    create table(:meta_columns, primary_key: false) do
      add :id,            :binary_id, primary_key: true
      add :meta_model_id, references(:meta_models, type: :binary_id, on_delete: :delete_all), null: false
      add :nombre,        :string, null: false
      add :etiqueta,      :string
      add :tipo,          :string, null: false, default: "string"
      add :longitud,      :integer
      add :nullable,      :boolean, default: true, null: false
      add :default_value, :string
      add :orden,         :integer, default: 0, null: false
      add :es_pk,         :boolean, default: false, null: false

      timestamps()
    end

    create index(:meta_columns, [:meta_model_id])
    create unique_index(:meta_columns, [:meta_model_id, :nombre])
  end
end
