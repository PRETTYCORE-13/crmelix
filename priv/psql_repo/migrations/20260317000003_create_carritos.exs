defmodule Prettycore.Repo.Migrations.CreateCarritos do
  use Ecto.Migration

  def change do
    create table(:carritos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :estado, :string, default: "activo", null: false
      timestamps(type: :utc_datetime)
    end

    create index(:carritos, [:user_id])
    create index(:carritos, [:user_id, :estado])

    create table(:carrito_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :carrito_id, references(:carritos, type: :binary_id, on_delete: :delete_all), null: false
      add :producto_codigo, :string, null: false
      add :cantidad, :integer, default: 1, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:carrito_items, [:carrito_id])
    create unique_index(:carrito_items, [:carrito_id, :producto_codigo])
  end
end
