defmodule Prettycore.PsqlRepo.Migrations.AddCamposToClientes do
  use Ecto.Migration

  def change do
    alter table(:clientes) do
      add_if_not_exists :nombre,   :string
      add_if_not_exists :rfc,      :string
      add_if_not_exists :email,    :string
      add_if_not_exists :telefono, :string
      add_if_not_exists :activo,   :boolean, default: true
      add_if_not_exists :inserted_at, :naive_datetime
      add_if_not_exists :updated_at,  :naive_datetime
    end
  end
end
