defmodule Prettycore.PsqlRepo.Migrations.CreateClientes do
  use Ecto.Migration

  def change do
    create table(:clientes) do
      add :nombre,   :string, null: false
      add :rfc,      :string
      add :email,    :string
      add :telefono, :string
      add :activo,   :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:clientes, [:rfc])
  end
end
