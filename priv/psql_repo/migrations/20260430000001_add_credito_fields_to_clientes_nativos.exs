defmodule Prettycore.PsqlRepo.Migrations.AddCreditoFieldsToClientesNativos do
  use Ecto.Migration

  def change do
    alter table(:clientes_nativos) do
      add :tipo_cliente,   :string,  default: nil
      add :tipo_pago,      :string,  default: "contado"
      add :limite_credito, :decimal, default: 0
      add :dias_credito,   :integer, default: 0
    end
  end
end
