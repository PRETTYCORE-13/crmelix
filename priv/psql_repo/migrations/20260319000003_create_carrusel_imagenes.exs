defmodule Prettycore.PsqlRepo.Migrations.CreateCarruselImagenes do
  use Ecto.Migration

  def change do
    create table(:carrusel_imagenes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :url, :string, null: false
      add :titulo, :string
      add :orden, :integer, default: 0, null: false
      add :activo, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:carrusel_imagenes, [:orden])
  end
end
