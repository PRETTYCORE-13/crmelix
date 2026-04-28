# lib/prettycore_web/controllers/session_controller.ex
defmodule PrettycoreWeb.SessionController do
  use PrettycoreWeb, :controller
  alias Prettycore.Auth
  alias Prettycore.Api.Client, as: Api
  alias Prettycore.SysAdmin
  require Logger

  def create(conn, %{"username" => user, "password" => pass}) do
    caso = Auth.authenticate(user, pass)
    config = SysAdmin.get_config()
    modo_nativo = config.modo_nativo == true

    case caso do
      {:ok, user_struct} ->
        user_id  = Map.get(user_struct, :id, user)
        email    = Map.get(user_struct, :email, user)
        username = Map.get(user_struct, :username, user)
        role     = Map.get(user_struct, :role, "user")

        if role == "sysadmin" do
          conn
          |> put_session(:user_id, user_id)
          |> put_session(:user_email, email)
          |> put_session(:user_name, username)
          |> put_session(:role, "sysadmin")
          |> put_session(:frog_token, nil)
          |> configure_session(renew: true)
          |> track_new_session(user_id)
          |> redirect(to: ~p"/sysadmin")
        else
          # En modo nativo no se obtiene token Frog ni se precargan catálogos
          frog_token = if modo_nativo, do: nil, else: get_frog_token(user_struct)

          dest =
            cond do
              role == "cliente_nativo" -> ~p"/admin/tienda"
              modo_nativo              -> ~p"/admin/tienda"
              true                     -> ~p"/admin/loading"
            end

          conn_with_session =
            conn
            |> put_session(:user_id, user_id)
            |> put_session(:user_email, email)
            |> put_session(:user_name, username)
            |> put_session(:role, role)
            |> put_session(:frog_token, frog_token)
            |> configure_session(renew: true)

          conn_tracked =
            if role == "cliente_nativo",
              do: conn_with_session,
              else: track_new_session(conn_with_session, user_id)

          redirect(conn_tracked, to: dest)
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Usuario o contraseña incorrectos")
        |> redirect(to: ~p"/")
    end
  end

  def delete(conn, _params) do
    session_token = get_session(conn, :session_token)
    Task.start(fn -> Auth.close_user_session(session_token) end)

    :persistent_term.erase(:cache_cte_clientes)
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp track_new_session(conn, user_id) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    user_agent = get_req_header(conn, "user-agent") |> List.first() || ""

    # Consolidar: cerrar duplicados del mismo dispositivo y reusar la sesión más reciente.
    # Si no existe ninguna, crear una nueva.
    session_token =
      case Auth.consolidate_device_sessions(user_id, ip, user_agent) do
        nil ->
          token = Ecto.UUID.generate()
          parsed = parse_user_agent(user_agent)
          now = DateTime.truncate(DateTime.utc_now(), :second)

          Auth.create_user_session(%{
            user_id: user_id,
            session_token: token,
            ip_address: ip,
            user_agent: user_agent,
            device_type: parsed.device_type,
            browser: parsed.browser,
            os: parsed.os,
            last_seen_at: now
          })

          token

        existing_token ->
          existing_token
      end

    put_session(conn, :session_token, session_token)
  end

  defp parse_user_agent(ua) do
    ua_lower = String.downcase(ua)

    device_type =
      cond do
        String.contains?(ua_lower, "iphone") -> "Mobile"
        String.contains?(ua_lower, "android") and String.contains?(ua_lower, "mobile") -> "Mobile"
        String.contains?(ua_lower, "ipad") -> "Tablet"
        String.contains?(ua_lower, "android") and not String.contains?(ua_lower, "mobile") -> "Tablet"
        true -> "Desktop"
      end

    browser =
      cond do
        String.contains?(ua_lower, "edg/") -> "Edge"
        String.contains?(ua_lower, "opr/") or String.contains?(ua_lower, "opera") -> "Opera"
        String.contains?(ua_lower, "firefox/") -> "Firefox"
        String.contains?(ua_lower, "chrome/") -> "Chrome"
        String.contains?(ua_lower, "safari/") -> "Safari"
        true -> "Otro"
      end

    os =
      cond do
        String.contains?(ua_lower, "windows") -> "Windows"
        String.contains?(ua_lower, "android") -> "Android"
        String.contains?(ua_lower, "iphone") or String.contains?(ua_lower, "ipad") -> "iOS"
        String.contains?(ua_lower, "mac os") -> "macOS"
        String.contains?(ua_lower, "linux") -> "Linux"
        true -> "Otro"
      end

    %{device_type: device_type, browser: browser, os: os}
  end

  defp get_frog_token(user_struct) do
    usuario_frog = Map.get(user_struct, :usuario_frog)

    if usuario_frog && usuario_frog != "" do
      case Api.get_frog_credentials(usuario_frog) do
        {:ok, token} ->
          Logger.info("FROG token obtenido para usuario: #{usuario_frog}")
          token

        {:error, reason} ->
          Logger.warning("No se pudo obtener FROG token: #{inspect(reason)}")
          nil
      end
    else
      nil
    end
  end
end
