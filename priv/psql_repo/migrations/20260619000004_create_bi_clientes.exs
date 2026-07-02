defmodule Prettycore.PsqlRepo.Migrations.CreateBiClientes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:bi_clientes) do
      add :udn,             :string
      add :id_cliente,      :string
      add :direccion,       :string
      add :nombre_comercial,:string
      add :preventa,        :string
      add :reparto,         :string

      timestamps()
    end

    create index(:bi_clientes, [:id_cliente])
    create index(:bi_clientes, [:udn])
  end
end
