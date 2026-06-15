defmodule Prettycore.Catalogos.Clientes.Cliente do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :nombre, :rfc, :email, :telefono, :activo,
                                  :inserted_at, :updated_at]}

  schema "clientes" do
    field :nombre,   :string
    field :rfc,      :string
    field :email,    :string
    field :telefono, :string
    field :activo,   :boolean, default: true

    timestamps()
  end

  def changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:nombre, :rfc, :email, :telefono, :activo])
    |> validate_required([:nombre])
    |> unique_constraint(:rfc)
  end
end
