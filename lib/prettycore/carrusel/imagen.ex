defmodule Prettycore.Carrusel.Imagen do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "carrusel_imagenes" do
    field :url, :string
    field :titulo, :string
    field :orden, :integer, default: 0
    field :activo, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(imagen, attrs) do
    imagen
    |> cast(attrs, [:url, :titulo, :orden, :activo])
    |> validate_required([:url])
  end
end
