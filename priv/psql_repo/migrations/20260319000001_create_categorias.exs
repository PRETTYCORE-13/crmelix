defmodule Prettycore.PsqlRepo.Migrations.CreateCategorias do
  use Ecto.Migration

  def change do
    create table(:categorias, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nombre, :string, null: false
      add :imagen_url, :string
      add :orden, :integer, default: 0, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:categorias, [:nombre])
    create index(:categorias, [:orden])
  end
end
