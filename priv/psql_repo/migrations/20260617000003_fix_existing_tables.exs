defmodule Prettycore.PsqlRepo.Migrations.FixExistingTables do
  use Ecto.Migration

  def change do
    # Agregar supercategoria_id a categorias si no existe
    alter table(:categorias) do
      add_if_not_exists :supercategoria_id, :integer
    end

    create_if_not_exists index(:categorias, [:supercategoria_id])

    # Agregar columnas faltantes a clientes si no existen
    alter table(:clientes) do
      add_if_not_exists :nombre,       :string
      add_if_not_exists :rfc,          :string
      add_if_not_exists :email,        :string
      add_if_not_exists :telefono,     :string
      add_if_not_exists :activo,       :boolean, default: true
      add_if_not_exists :inserted_at,  :naive_datetime
      add_if_not_exists :updated_at,   :naive_datetime
    end
  end
end
