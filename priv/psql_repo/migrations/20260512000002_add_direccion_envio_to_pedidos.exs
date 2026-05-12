defmodule Prettycore.PsqlRepo.Migrations.AddDireccionEnvioToPedidos do
  use Ecto.Migration

  def change do
    alter table(:pedidos) do
      add :direccion_envio, :string, null: true
    end
  end
end
