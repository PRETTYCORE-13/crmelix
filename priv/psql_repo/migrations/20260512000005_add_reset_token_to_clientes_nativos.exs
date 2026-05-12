defmodule Prettycore.PsqlRepo.Migrations.AddResetTokenToClientesNativos do
  use Ecto.Migration

  def change do
    alter table(:clientes_nativos) do
      add :reset_token,            :string, null: true
      add :reset_token_expires_at, :utc_datetime, null: true
    end

    create unique_index(:clientes_nativos, [:reset_token],
      where: "reset_token IS NOT NULL",
      name: :clientes_nativos_reset_token_index
    )
  end
end
