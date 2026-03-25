defmodule Prettycore.Precios.Precio do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "precios" do
    field :producto_codigo, :string
    field :precio, :float
    field :cliente_codigo, :string
    field :dir_codigo, :string
    field :lista_precio, :integer
    field :unidad, :string
    timestamps()
  end

  def changeset(precio, attrs) do
    precio
    |> cast(attrs, [:producto_codigo, :precio, :cliente_codigo, :dir_codigo, :lista_precio, :unidad])
    |> validate_required([:producto_codigo, :precio, :cliente_codigo, :dir_codigo])
  end
end
