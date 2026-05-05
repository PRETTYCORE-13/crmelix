defmodule Prettycore.Pedidos.Pedido do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pedidos" do
    field :user_id, :binary_id
    field :cliente_codigo, :string
    field :dir_codigo, :string
    field :estado, :string, default: "pendiente"
    field :metodo_pago, :string, default: "contado"
    field :notas, :string
    has_many :items, Prettycore.Pedidos.PedidoItem
    timestamps()
  end

  @estados ~w(pendiente procesando enviado entregado cancelado cancelacion_solicitada)

  def changeset(pedido, attrs) do
    pedido
    |> cast(attrs, [:user_id, :cliente_codigo, :dir_codigo, :estado, :metodo_pago, :notas])
    |> validate_required([:user_id, :estado])
    |> validate_inclusion(:estado, @estados)
  end

  def estados, do: @estados
end
