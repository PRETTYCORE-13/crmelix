defmodule Prettycore.Meta.MetaModel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "meta_models" do
    field :nombre,       :string
    field :descripcion,  :string
    field :tabla_db,     :string
    field :activo,       :boolean, default: true
    field :tabla_creada, :boolean, default: false

    has_many :columnas,   Prettycore.Meta.MetaColumn,   foreign_key: :meta_model_id
    has_many :endpoints,  Prettycore.Meta.MetaEndpoint, foreign_key: :meta_model_id
    has_many :relaciones, Prettycore.Meta.MetaRelation, foreign_key: :meta_model_id

    timestamps()
  end

  def changeset(model, attrs) do
    model
    |> cast(attrs, [:nombre, :descripcion, :tabla_db, :activo])
    |> validate_required([:nombre, :tabla_db])
    |> validate_format(:nombre,   ~r/^[a-zA-Z][a-zA-Z0-9_]*$/, message: "solo letras, números y guión bajo, sin espacios")
    |> validate_format(:tabla_db, ~r/^[a-z][a-z0-9_]*$/, message: "solo minúsculas, números y guión bajo")
    |> unique_constraint(:nombre)
    |> unique_constraint(:tabla_db)
  end

  def status_changeset(model, attrs) do
    cast(model, attrs, [:tabla_creada, :activo])
  end
end
