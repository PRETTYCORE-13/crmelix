defmodule Prettycore.BI.Producto do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, except: [:__meta__]}
  schema "bi_productos" do
    field :id_producto,     :string
    field :nombre_producto, :string
    field :fabricante,      :string
    field :marca,           :string

    timestamps()
  end

  def changeset(producto, attrs) do
    producto
    |> cast(attrs, [:id_producto, :nombre_producto, :fabricante, :marca])
  end
end
