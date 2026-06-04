defmodule Prettycore.SysAdmin.Config do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}

  schema "system_config" do
    field :foto, :string
    field :permitir_edicion, :boolean, default: true
    field :banda_texto, :string
    field :banda_color, :string
    field :timezone,    :string, default: "America/Mexico_City"

    timestamps(type: :utc_datetime)
  end

  def changeset(config, attrs) do
    config
    |> cast(attrs, [:foto, :permitir_edicion, :banda_texto, :banda_color, :timezone])
    |> validate_required([])
  end
end
