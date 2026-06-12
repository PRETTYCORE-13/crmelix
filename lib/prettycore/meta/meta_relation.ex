defmodule Prettycore.Meta.MetaRelation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @tipos ~w(belongs_to has_many)

  schema "meta_relations" do
    field :meta_model_id,     :binary_id
    field :contexto_destino_id, :binary_id
    field :tipo,              :string
    field :campo_fk,          :string
    field :alias,             :string

    belongs_to :contexto,   Prettycore.Meta.MetaModel, foreign_key: :meta_model_id,     define_field: false
    belongs_to :destino,  Prettycore.Meta.MetaModel, foreign_key: :contexto_destino_id, define_field: false

    timestamps()
  end

  def changeset(rel, attrs) do
    rel
    |> cast(attrs, [:meta_model_id, :contexto_destino_id, :tipo, :campo_fk, :alias])
    |> validate_required([:meta_model_id, :contexto_destino_id, :tipo, :campo_fk])
    |> validate_inclusion(:tipo, @tipos, message: "debe ser belongs_to o has_many")
    |> unique_constraint([:meta_model_id, :campo_fk])
  end

  def tipos, do: @tipos
end
