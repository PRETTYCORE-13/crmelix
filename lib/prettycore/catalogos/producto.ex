# lib/prettycore/catalogos/productos/producto.ex
defmodule Prettycore.Catalogos.Productos.Producto do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :codigo, :descripcion, :precio, :activo, :imagen,
                                  :categoria_id, :marca_id, :gama_id, :unidad_medida_id,
                                  :inserted_at, :updated_at]}
  schema "productos" do
    field :codigo,     :string
    field :descripcion,:string
    field :precio,     :float
    field :activo,     :boolean, default: true
    field :imagen,     :string

    # Relaciones con otros schemas del mismo subcontexto
    belongs_to :categoria, Prettycore.Catalogos.Productos.Categoria
    belongs_to :marca, Prettycore.Catalogos.Productos.Marca
    belongs_to :gama, Prettycore.Catalogos.Productos.Gama
    belongs_to :unidad_medida, Prettycore.Catalogos.Productos.UnidadMedida

    timestamps()
  end

  def changeset(producto, attrs) do
    producto
    |> cast(attrs, [:codigo, :descripcion, :precio, :activo, :imagen,
                    :categoria_id, :marca_id, :gama_id, :unidad_medida_id])
    |> validate_required([:codigo, :descripcion])
    |> unique_constraint(:codigo)
    |> validate_number(:id, greater_than: 0)  # ← Validar ID > 0
  end
end
