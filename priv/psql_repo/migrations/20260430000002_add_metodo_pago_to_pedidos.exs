defmodule Prettycore.PsqlRepo.Migrations.AddMetodoPagoToPedidos do
  use Ecto.Migration

  def change do
    alter table(:pedidos) do
      add :metodo_pago, :string, default: "contado"
    end
  end
end
