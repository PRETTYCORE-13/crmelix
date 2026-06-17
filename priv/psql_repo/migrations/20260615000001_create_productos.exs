defmodule Prettycore.PsqlRepo.Migrations.CreateProductos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:productos) do
      add :codigo,           :string, null: false
      add :descripcion,      :string, null: false
      add :precio,           :float
      add :activo,           :boolean, default: true, null: false
      add :categoria_id,     :integer
      add :marca_id,         :integer
      add :gama_id,          :integer
      add :unidad_medida_id, :integer

      timestamps()
    end

    create_if_not_exists unique_index(:productos, [:codigo])
  end
end
