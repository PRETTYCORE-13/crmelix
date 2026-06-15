defmodule Prettycore.PsqlRepo.Migrations.CreateCategorias do
  use Ecto.Migration

  def change do
    create table(:categorias) do
      add :nombre,            :string, null: false
      add :activo,            :boolean, default: true, null: false
      add :supercategoria_id, references(:supercategorias, on_delete: :nilify_all)
      timestamps()
    end

    create unique_index(:categorias, [:nombre])
    create index(:categorias, [:supercategoria_id])
  end
end
