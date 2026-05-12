defmodule Prettycore.Pedidos.UserAddress do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_addresses" do
    field :user_id, :binary_id
    field :direccion, :string
    field :form_data, :map
    timestamps()
  end

  def changeset(addr, attrs) do
    addr
    |> cast(attrs, [:user_id, :direccion, :form_data])
    |> validate_required([:user_id, :direccion])
  end
end
