defmodule Prettycore.Repo.Migrations.CreatePedidos do
  use Ecto.Migration

  def change do
    create table(:pedidos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :cliente_codigo, :string
      add :dir_codigo, :string
      add :estado, :string, default: "pendiente", null: false
      add :notas, :text
      timestamps()
    end

    create index(:pedidos, [:user_id])
    create index(:pedidos, [:estado])

    create table(:pedido_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pedido_id, references(:pedidos, type: :binary_id, on_delete: :delete_all), null: false
      add :producto_codigo, :string, null: false
      add :descripcion, :string
      add :cantidad, :integer, null: false, default: 1
      add :precio_unitario, :float, default: 0.0
      timestamps()
    end

    create index(:pedido_items, [:pedido_id])
  end
end
