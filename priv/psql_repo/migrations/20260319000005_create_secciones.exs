defmodule Prettycore.PsqlRepo.Migrations.CreateSecciones do
  use Ecto.Migration

  def change do
    create table(:secciones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :nombre, :string, null: false
      add :tipo, :string, null: false
      add :orden, :integer, default: 0
      add :activo, :boolean, default: true
      timestamps(type: :utc_datetime)
    end
  end
end
