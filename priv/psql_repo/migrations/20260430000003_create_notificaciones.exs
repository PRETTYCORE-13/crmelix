defmodule Prettycore.PsqlRepo.Migrations.CreateNotificaciones do
  use Ecto.Migration

  def change do
    create table(:notificaciones, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :titulo, :string, null: false
      add :mensaje, :string
      add :tipo, :string, default: "info"
      add :leida, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:notificaciones, [:user_id, :inserted_at])
    create index(:notificaciones, [:user_id, :leida])
  end
end
