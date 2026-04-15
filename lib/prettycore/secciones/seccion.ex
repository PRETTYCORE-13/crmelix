defmodule Prettycore.Secciones.Seccion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @tipos ~w(carrusel productos top10 favoritos destacados ofertas publicidad envios)

  schema "secciones" do
    field :nombre, :string
    field :tipo, :string
    field :orden, :integer, default: 0
    field :activo, :boolean, default: true
    field :config, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def changeset(s, attrs) do
    s
    |> cast(attrs, [:nombre, :tipo, :orden, :activo, :config])
    |> validate_required([:nombre, :tipo])
    |> validate_inclusion(:tipo, @tipos)
  end

  def tipos, do: @tipos

  def tipo_label("carrusel"),   do: "Carrusel"
  def tipo_label("productos"),  do: "Tienda"
  def tipo_label("top10"),      do: "Top 10"
  def tipo_label("favoritos"),  do: "Favoritos"
  def tipo_label("destacados"), do: "Carrusel Dest."
  def tipo_label("publicidad"), do: "Publicidad"
  def tipo_label("ofertas"),    do: "Top10, Dest. y Favs"
  def tipo_label("envios"),     do: "Envíos"
  def tipo_label(t),            do: t
end
