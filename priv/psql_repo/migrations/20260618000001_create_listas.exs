defmodule Prettycore.PsqlRepo.Migrations.CreateListas do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:listas) do
      add :nombre,     :string, null: false
      add :activo,     :boolean, default: true, null: false
      add :cliente_id, :integer
      timestamps()
    end

    create_if_not_exists index(:listas, [:cliente_id])
  end
end
