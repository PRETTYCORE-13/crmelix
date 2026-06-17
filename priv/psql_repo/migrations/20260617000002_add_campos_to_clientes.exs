defmodule Prettycore.PsqlRepo.Migrations.AddCamposToClientes do
  use Ecto.Migration

  def change do
    alter table(:clientes) do
      add_if_not_exists :rfc,      :string
      add_if_not_exists :email,    :string
      add_if_not_exists :telefono, :string
      add_if_not_exists :activo,   :boolean, default: true
    end
  end
end
