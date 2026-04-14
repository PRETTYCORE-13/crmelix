defmodule Prettycore.PsqlRepo.Migrations.DropCarritosUserFkey do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE carritos DROP CONSTRAINT IF EXISTS carritos_user_id_fkey"
  end

  def down do
    # No recreamos el FK porque no sabemos a qué tabla apuntaba originalmente
    :ok
  end
end
