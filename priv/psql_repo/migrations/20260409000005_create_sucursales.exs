defmodule Prettycore.PsqlRepo.Migrations.CreateSucursales do
  use Ecto.Migration

  def change do
    create table(:sucursales, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :numero, :integer, null: false
      add :nombre, :string, null: false
      add :direccion, :string
      add :activo, :boolean, default: true, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:sucursales, [:numero])
  end
end
