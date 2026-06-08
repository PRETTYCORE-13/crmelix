defmodule PrettycoreWeb.Plugs.ApiAuth do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Prettycore.ApiTokens

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, api_token} <- ApiTokens.validar_token(token) do
      assign(conn, :api_token, api_token)
    else
      _ ->
        conn
        |> put_status(401)
        |> json(%{ok: false, error: "Token Bearer inválido o no proporcionado"})
        |> halt()
    end
  end
end
