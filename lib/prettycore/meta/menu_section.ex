defmodule Prettycore.Meta.MenuSection do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "menu_sections" do
    field :nombre,   :string
    field :etiqueta, :string
    field :icono,    :string
    field :orden,    :integer, default: 0
    field :ruta,     :string
    field :parent_id, :binary_id
    field :activo,   :boolean, default: true
    field :roles,    {:array, :string}, default: []

    timestamps()
  end

  def changeset(section, attrs) do
    section
    |> cast(attrs, [:nombre, :etiqueta, :icono, :orden, :ruta, :parent_id, :activo, :roles])
    |> validate_required([:nombre, :etiqueta])
    |> validate_format(:nombre, ~r/^[a-z][a-z0-9_-]*$/, message: "solo minúsculas, números, guión")
    |> unique_constraint(:nombre)
  end
end
