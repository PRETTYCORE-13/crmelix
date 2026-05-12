defmodule Prettycore.PsqlRepo.Migrations.AddPedidoIdToNotificaciones do
  use Ecto.Migration

  def change do
    alter table(:notificaciones) do
      add :pedido_id, :uuid, null: true
    end
  end
end
