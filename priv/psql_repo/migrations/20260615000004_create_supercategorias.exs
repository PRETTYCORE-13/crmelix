defmodule Prettycore.PsqlRepo.Migrations.CreateSupercategorias do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:supercategorias) do
      add :nombre, :string, null: false
      add :activo, :boolean, default: true, null: false
      timestamps()
    end

    create_if_not_exists unique_index(:supercategorias, [:nombre])
  end
end
