defmodule Prettycore.ApiTokens.ApiToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_tokens" do
    field :token, :string
    field :activo, :boolean, default: true
    belongs_to :user, Prettycore.Auth.AuthUser

    timestamps()
  end

  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:token, :user_id, :activo])
    |> validate_required([:token, :user_id])
    |> unique_constraint(:token)
    |> unique_constraint(:user_id)
  end
end
