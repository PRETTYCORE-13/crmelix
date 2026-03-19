defmodule Prettycore.PsqlRepo.Migrations.CreateCategoriaProductos do
  use Ecto.Migration

  def change do
    create table(:categoria_productos, primary_key: false) do
      add :categoria_id, references(:categorias, type: :binary_id, on_delete: :delete_all), null: false
      add :producto_codigo, references(:productos, column: :codigo, type: :string, on_delete: :delete_all), null: false
    end

    create index(:categoria_productos, [:categoria_id])
    create index(:categoria_productos, [:producto_codigo])
    create unique_index(:categoria_productos, [:categoria_id, :producto_codigo])
  end
end
