defmodule Prettycore.PsqlRepo.Migrations.CreateUserAddresses do
  use Ecto.Migration

  def change do
    create table(:user_addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false
      add :direccion, :text, null: false
      timestamps()
    end

    create index(:user_addresses, [:user_id])
  end
end
