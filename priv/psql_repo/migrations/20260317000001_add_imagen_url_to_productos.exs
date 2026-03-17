defmodule Prettycore.PsqlRepo.Migrations.AddImagenUrlToProductos do
  use Ecto.Migration

  def change do
    alter table(:productos) do
      add :imagen_url, :string
    end
  end
end
