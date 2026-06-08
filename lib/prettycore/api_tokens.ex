defmodule Prettycore.ApiTokens do
  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.ApiTokens.ApiToken
  alias Prettycore.Auth
  alias Prettycore.Auth.AuthUser

  @doc """
  Valida credenciales sysadmin y devuelve (o crea) un Bearer token.
  Solo usuarios con rol sysadmin pueden obtener tokens de API.
  """
  def autenticar_y_obtener_token(usuario, contrasena) do
    with %AuthUser{} = user <- Auth.get_user_by_username(usuario),
         true <- user.role == "sysadmin",
         true <- user.active,
         true <- AuthUser.verify_password(user, contrasena) do
      obtener_o_crear_token(user.id)
    else
      _ -> {:error, :credenciales_invalidas}
    end
  end

  @doc "Valida un Bearer token. Retorna {:ok, api_token} o {:error, :invalido}."
  def validar_token(token_string) do
    case PsqlRepo.get_by(ApiToken, token: token_string, activo: true) do
      nil -> {:error, :invalido}
      token -> {:ok, token}
    end
  end

  defp obtener_o_crear_token(user_id) do
    case PsqlRepo.get_by(ApiToken, user_id: user_id) do
      %ApiToken{activo: true} = t ->
        {:ok, t}

      %ApiToken{activo: false} = t ->
        t
        |> ApiToken.changeset(%{activo: true})
        |> PsqlRepo.update()

      nil ->
        %ApiToken{}
        |> ApiToken.changeset(%{token: generar_token(), user_id: user_id})
        |> PsqlRepo.insert()
    end
  end

  defp generar_token do
    :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
  end
end
