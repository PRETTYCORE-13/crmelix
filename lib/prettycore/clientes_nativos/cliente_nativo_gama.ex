defmodule Prettycore.ClientesNativos.ClienteNativoGama do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "cliente_nativo_gamas" do
    field :cliente_nativo_id, :binary_id
    field :gama_numero,       :integer
    timestamps(type: :utc_datetime)
  end
end
