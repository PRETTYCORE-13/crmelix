defmodule Prettycore.PsqlRepo.Migrations.CreateClientesNativos do
  use Ecto.Migration

  def change do
    create table(:clientes_nativos, primary_key: false) do
      add :id,            :binary_id,   primary_key: true, default: fragment("gen_random_uuid()")
      add :nombre,        :string,      null: false
      add :username,      :string,      null: false
      add :email,         :string
      add :password_hash, :string,      null: false
      add :telefono,      :string
      add :rfc,           :string
      add :direccion,     :string
      add :notas,         :text
      add :activo,        :boolean,     default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:clientes_nativos, [:username])
    create unique_index(:clientes_nativos, [:email], where: "email IS NOT NULL AND email <> ''")
    create index(:clientes_nativos, [:activo])
  end
end
