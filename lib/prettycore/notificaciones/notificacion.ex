defmodule Prettycore.Notificaciones.Notificacion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notificaciones" do
    field :user_id,  :binary_id
    field :titulo,   :string
    field :mensaje,  :string
    field :tipo,     :string, default: "info"
    field :leida,    :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(notif, attrs) do
    notif
    |> cast(attrs, [:user_id, :titulo, :mensaje, :tipo, :leida])
    |> validate_required([:user_id, :titulo, :mensaje])
  end
end
