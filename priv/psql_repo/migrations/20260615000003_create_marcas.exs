defmodule Prettycore.PsqlRepo.Migrations.CreateMarcas do
  use Ecto.Migration

  def change do
    create table(:marcas) do
      add :nombre, :string, null: false
      add :activo, :boolean, default: true, null: false
      timestamps()
    end

    create unique_index(:marcas, [:nombre])
  end
end
