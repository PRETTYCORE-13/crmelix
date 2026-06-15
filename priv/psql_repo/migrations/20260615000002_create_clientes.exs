defmodule Prettycore.PsqlRepo.Migrations.CreateClientes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:clientes) do
      add :nombre,   :string, null: false
      add :rfc,      :string
      add :email,    :string
      add :telefono, :string
      add :activo,   :boolean, default: true, null: false

      timestamps()
    end

  end
end
