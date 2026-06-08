defmodule Prettycore.PsqlRepo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :activo, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:api_tokens, [:token])
    create unique_index(:api_tokens, [:user_id])
  end
end
