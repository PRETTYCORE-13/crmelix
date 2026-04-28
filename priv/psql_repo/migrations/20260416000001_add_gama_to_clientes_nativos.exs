defmodule Prettycore.PsqlRepo.Migrations.AddGamaToClientesNativos do
  use Ecto.Migration

  def change do
    alter table(:clientes_nativos) do
      add :gama, :integer, default: 1
    end
  end
end
