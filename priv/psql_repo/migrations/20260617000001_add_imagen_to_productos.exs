defmodule Prettycore.PsqlRepo.Migrations.AddImagenToProductos do
  use Ecto.Migration

  def change do
    alter table(:productos) do
      add :imagen, :text
    end
  end
end
