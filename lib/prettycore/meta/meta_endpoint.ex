defmodule Prettycore.Meta.MetaEndpoint do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @operaciones ~w(lista show buscar crear actualizar eliminar)

  schema "meta_endpoints" do
    field :meta_model_id, :binary_id
    field :operacion,     :string
    field :activo,        :boolean, default: true
    field :requiere_auth, :boolean, default: true

    belongs_to :contexto, Prettycore.Meta.MetaModel, foreign_key: :meta_model_id, define_field: false

    timestamps()
  end

  def changeset(ep, attrs) do
    ep
    |> cast(attrs, [:meta_model_id, :operacion, :activo, :requiere_auth])
    |> validate_required([:meta_model_id, :operacion])
    |> validate_inclusion(:operacion, @operaciones, message: "operación inválida")
    |> unique_constraint([:meta_model_id, :operacion])
  end

  def operaciones, do: @operaciones
end
