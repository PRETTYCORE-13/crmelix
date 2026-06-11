defmodule Prettycore.Meta.MetaColumn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @tipos ~w(string text integer float boolean date datetime uuid)
  @reservados ~w(id inserted_at updated_at)

  schema "meta_columns" do
    field :meta_model_id, :binary_id
    field :nombre,        :string
    field :etiqueta,      :string
    field :tipo,          :string, default: "string"
    field :longitud,      :integer
    field :nullable,      :boolean, default: true
    field :default_value, :string
    field :orden,         :integer, default: 0
    field :es_pk,         :boolean, default: false
    field :requerido,     :boolean, default: false
    field :unico,         :boolean, default: false
    field :min_longitud,  :integer
    field :max_longitud,  :integer

    belongs_to :modelo, Prettycore.Meta.MetaModel, foreign_key: :meta_model_id, define_field: false

    timestamps()
  end

  def changeset(col, attrs) do
    col
    |> cast(attrs, [:meta_model_id, :nombre, :etiqueta, :tipo, :longitud, :nullable,
                    :default_value, :orden, :es_pk, :requerido, :unico, :min_longitud, :max_longitud])
    |> validate_required([:meta_model_id, :nombre, :tipo])
    |> validate_inclusion(:tipo, @tipos, message: "tipo inválido")
    |> validate_format(:nombre, ~r/^[a-z][a-z0-9_]*$/, message: "solo minúsculas, números y guión bajo")
    |> validate_exclusion(:nombre, @reservados, message: "nombre reservado (id, inserted_at, updated_at son generados automáticamente)")
    |> unique_constraint([:meta_model_id, :nombre])
  end

  def tipos, do: @tipos
end
