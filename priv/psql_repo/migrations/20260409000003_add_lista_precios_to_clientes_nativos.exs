defmodule Prettycore.PsqlRepo.Migrations.AddListaPreciosToClientesNativos do
  use Ecto.Migration

  def change do
    alter table(:clientes_nativos) do
      add :lista_precios, :integer, default: 1, null: false
    end
  end
end
