defmodule Prettycore.PsqlRepo.Migrations.CreateListaItems do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:lista_items) do
      add :lista_id,    :integer, null: false
      add :producto_id, :integer, null: false
      timestamps()
    end

    create_if_not_exists index(:lista_items, [:lista_id])
    create_if_not_exists index(:lista_items, [:producto_id])
    create_if_not_exists unique_index(:lista_items, [:lista_id, :producto_id])
  end
end
