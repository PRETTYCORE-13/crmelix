defmodule Prettycore.PsqlRepo.Migrations.AddSucursalToClientesNativos do
  use Ecto.Migration

  def change do
    alter table(:clientes_nativos) do
      add :sucursal_numero, :integer
    end
  end
end
