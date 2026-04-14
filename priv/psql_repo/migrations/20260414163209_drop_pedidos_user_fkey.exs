defmodule Prettycore.PsqlRepo.Migrations.DropPedidosUserFkey do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedidos_user_id_fkey"
  end

  def down do
    :ok
  end
end
