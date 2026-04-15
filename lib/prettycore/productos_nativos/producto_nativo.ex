defmodule Prettycore.ProductosNativos.ProductoNativo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:codigo, :string, autogenerate: false}

  schema "productos_nativos" do
    field :descripcion, :string
    field :desc_corta,  :string
    field :precio_base, :float, default: 0.0
    field :imagen_url,  :string
    field :activo,      :boolean, default: true
    field :stock,       :integer
    field :unidad,      :string, default: "PZA"
    field :marca,          :string
    field :notas,          :string
    field :categoria,      :string
    field :super_categoria, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(producto, attrs) do
    producto
    |> cast(attrs, [:codigo, :descripcion, :desc_corta, :precio_base, :imagen_url,
                    :activo, :stock, :unidad, :marca, :notas, :categoria, :super_categoria])
    |> validate_required([:codigo, :descripcion, :precio_base])
    |> validate_length(:codigo, min: 1, max: 50)
    |> validate_length(:descripcion, min: 2, max: 255)
    |> validate_length(:desc_corta, max: 40)
    |> validate_length(:notas, max: 40)
    |> validate_number(:precio_base, greater_than: 0, message: "El precio público debe ser mayor a 0")
    |> unique_constraint(:codigo, name: :productos_nativos_pkey)
  end
end
