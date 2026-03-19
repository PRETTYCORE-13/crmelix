defmodule Prettycore.PsqlRepo.Migrations.CreateSuperCategorias do
  use Ecto.Migration

  def change do
    create table(:super_categorias, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nombre, :string, null: false
      add :descripcion, :string
      add :imagen_url, :string
      add :orden, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:super_categorias, [:nombre])

    create table(:super_categoria_productos, primary_key: false) do
      add :super_categoria_id, references(:super_categorias, type: :binary_id, on_delete: :delete_all), null: false
      add :producto_codigo, references(:productos, column: :codigo, type: :string, on_delete: :delete_all), null: false
    end

    create unique_index(:super_categoria_productos, [:super_categoria_id, :producto_codigo])
  end
end
