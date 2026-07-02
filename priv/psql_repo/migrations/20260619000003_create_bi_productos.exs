defmodule Prettycore.PsqlRepo.Migrations.CreateBiProductos do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:bi_productos) do
      add :id_producto,     :string
      add :nombre_producto, :string
      add :fabricante,      :string
      add :marca,           :string

      timestamps()
    end

    create index(:bi_productos, [:id_producto])
  end
end
