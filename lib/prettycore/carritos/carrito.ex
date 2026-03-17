defmodule Prettycore.Carritos.Carrito do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "carritos" do
    field :estado, :string, default: "activo"
    belongs_to :user, Prettycore.Auth.AuthUser
    has_many :items, Prettycore.Carritos.CarritoItem
    timestamps(type: :utc_datetime)
  end

  def changeset(carrito, attrs) do
    carrito
    |> cast(attrs, [:user_id, :estado])
    |> validate_required([:user_id])
    |> validate_inclusion(:estado, ["activo", "completado", "cancelado"])
  end
end
