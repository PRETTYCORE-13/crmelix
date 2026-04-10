defmodule Prettycore.PsqlRepo.Migrations.AddCategoriaToProductosNativos do
  use Ecto.Migration

  def change do
    alter table(:productos_nativos) do
      add :categoria,       :string
      add :super_categoria, :string
    end
  end
end
