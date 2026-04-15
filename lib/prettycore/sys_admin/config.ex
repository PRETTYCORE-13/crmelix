defmodule Prettycore.SysAdmin.Config do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}

  schema "system_config" do
    field :usuario, :string
    field :instancia, :string
    field :token, :string
    field :url, :string
    field :foto, :string
    field :permitir_edicion, :boolean, default: true
    field :modo_nativo, :boolean, default: false
    field :banda_texto, :string
    field :banda_color, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:usuario, :instancia, :token, :url, :foto, :permitir_edicion, :modo_nativo, :banda_texto, :banda_color])
    |> validate_required([])
  end
end
