defmodule Prettycore.PsqlRepo.Migrations.CreateMenuSections do
  use Ecto.Migration

  def change do
    create table(:menu_sections, primary_key: false) do
      add :id,        :binary_id, primary_key: true
      add :nombre,    :string, null: false
      add :etiqueta,  :string, null: false
      add :icono,     :string
      add :orden,     :integer, default: 0, null: false
      add :ruta,      :string
      add :parent_id, :binary_id
      add :activo,    :boolean, default: true, null: false
      add :roles,     {:array, :string}, default: []

      timestamps()
    end

    create unique_index(:menu_sections, [:nombre])
    create index(:menu_sections, [:parent_id])
    create index(:menu_sections, [:orden])
  end
end
