defmodule Prettycore.BI.Cliente do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "bi_clientes" do
    field :udn,              :string
    field :id_cliente,       :string
    field :direccion,        :string
    field :nombre_comercial, :string
    field :preventa,         :string
    field :reparto,          :string

    timestamps()
  end

  def changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:udn, :id_cliente, :direccion, :nombre_comercial, :preventa, :reparto])
  end
end
