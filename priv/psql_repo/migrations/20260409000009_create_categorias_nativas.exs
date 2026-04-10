defmodule Prettycore.PsqlRepo.Migrations.CreateCategoriasNativas do
  use Ecto.Migration

  def change do
    create table(:categorias_nativas, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :nombre, :string, null: false
      add :activo, :boolean, default: true, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:categorias_nativas, [:nombre])

    create table(:super_categorias_nativas, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :nombre, :string, null: false
      add :activo, :boolean, default: true, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:super_categorias_nativas, [:nombre])
  end
end
