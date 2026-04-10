defmodule Prettycore.Auth do
  @moduledoc """
  Módulo de autenticación usando PostgreSQL.
  """
  require Logger

  alias Prettycore.PsqlRepo
  alias Prettycore.Auth.AuthUser
  alias Prettycore.Auth.UserSession

  # Cache simple en memoria para códigos de reset (en producción usar Redis/ETS)
  @reset_codes_table :password_reset_codes

  @doc """
  Autentica un usuario con username y password.
  """
  def authenticate(username, password)
      when is_binary(username) and is_binary(password) do
    case PsqlRepo.get_by(AuthUser, username: username) do
      nil ->
        # Buscar en clientes nativos
        case Prettycore.ClientesNativos.authenticate(username, password) do
          {:ok, cliente} ->
            {:ok, %{
              id:           cliente.id,
              email:        cliente.email || "",
              username:     cliente.username,
              role:         "cliente_nativo",
              usuario_frog: nil,
              permissions:  ["inicio", "tienda"]
            }}

          {:error, _} ->
            Pbkdf2.no_user_verify()
            {:error, :invalid_credentials}
        end

      user ->
        if user.active && AuthUser.verify_password(user, password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  @doc """
  Crea un nuevo usuario.
  """
  def create_user(attrs) do
    %AuthUser{}
    |> AuthUser.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def create_user_admin(attrs) do
    %AuthUser{}
    |> AuthUser.admin_changeset(attrs)
    |> PsqlRepo.insert()
  end

  @doc """
  Obtiene un usuario por username.
  """
  def get_user_by_username(username) do
    PsqlRepo.get_by(AuthUser, username: username)
  end

  @doc """
  Obtiene un usuario por ID.
  """
  def get_user(id) do
    PsqlRepo.get(AuthUser, id)
  end

  @doc """
  Lista todos los usuarios.
  """
  def list_users do
    PsqlRepo.all(AuthUser)
  end

  @doc """
  Actualiza un usuario.
  """
  def update_user(%AuthUser{} = user, attrs) do
    user
    |> AuthUser.update_changeset(attrs)
    |> PsqlRepo.update()
  end

  def delete_user(%AuthUser{} = user) do
    PsqlRepo.delete(user)
  end

  def toggle_permission(%AuthUser{} = user, permission) do
    current = user.permissions || ["inicio"]
    updated =
      if permission in current,
        do: List.delete(current, permission),
        else: [permission | current]
    update_user(user, %{permissions: updated})
  end

  @doc """
  Cambia el password de un usuario.
  """
  def change_password(%AuthUser{} = user, new_password) do
    user
    |> AuthUser.password_changeset(%{password: new_password})
    |> PsqlRepo.update()
  end

  # ============================================================
  # USER SESSION TRACKING
  # ============================================================

  @doc "Registra una nueva sesión al hacer login."
  def create_user_session(attrs) do
    %UserSession{}
    |> UserSession.changeset(attrs)
    |> PsqlRepo.insert()
  end

  @doc "Obtiene una sesión por su token."
  def get_user_session(session_token) when is_binary(session_token) do
    PsqlRepo.get_by(UserSession, session_token: session_token)
  end

  def get_user_session(_), do: nil

  @doc """
  Verifica si la sesión fue cerrada a la fuerza y toca last_seen_at si es necesario.
  Retorna :force_closed si el sysadmin la cerró, :ok en caso contrario.
  """
  def check_and_touch_session(session_token) when is_binary(session_token) do
    case get_user_session(session_token) do
      nil -> :ok
      %{logged_out_at: lo} when not is_nil(lo) -> :force_closed
      session ->
        now = DateTime.utc_now()
        threshold = DateTime.add(now, -5 * 60, :second)
        stale = is_nil(session.last_seen_at) or
                DateTime.compare(session.last_seen_at, threshold) == :lt

        if stale do
          session
          |> Ecto.Changeset.change(last_seen_at: DateTime.truncate(now, :second))
          |> PsqlRepo.update()
        end

        :ok
    end
  end

  def check_and_touch_session(_), do: :ok

  @doc "Marca la sesión como cerrada al hacer logout."
  def close_user_session(nil), do: :ok
  def close_user_session(session_token) when is_binary(session_token) do
    case get_user_session(session_token) do
      nil -> :ok
      session ->
        session
        |> Ecto.Changeset.change(logged_out_at: DateTime.truncate(DateTime.utc_now(), :second))
        |> PsqlRepo.update()
    end
  end

  @doc """
  Consolida sesiones abiertas del mismo dispositivo (user_id + ip + user_agent).
  Cierra todos los duplicados y retorna el token de la sesión más reciente,
  o nil si no existía ninguna (hay que crear una nueva).
  """
  def consolidate_device_sessions(user_id, ip, user_agent) do
    import Ecto.Query

    open_sessions =
      PsqlRepo.all(
        from s in UserSession,
          where: s.user_id == ^user_id
            and s.ip_address == ^ip
            and s.user_agent == ^user_agent
            and is_nil(s.logged_out_at),
          order_by: [desc: s.inserted_at]
      )

    case open_sessions do
      [] ->
        nil

      [latest | duplicates] ->
        if duplicates != [] do
          now = DateTime.truncate(DateTime.utc_now(), :second)
          dup_ids = Enum.map(duplicates, & &1.id)
          PsqlRepo.update_all(
            from(s in UserSession, where: s.id in ^dup_ids),
            set: [logged_out_at: now]
          )
        end

        latest.session_token
    end
  end

  @doc "Fuerza el cierre de una sesión específica por su ID (desde sysadmin)."
  def force_close_session(session_id) do
    case PsqlRepo.get(UserSession, session_id) do
      nil -> :ok
      session ->
        session
        |> Ecto.Changeset.change(logged_out_at: DateTime.truncate(DateTime.utc_now(), :second))
        |> PsqlRepo.update()
    end
  end

  @doc "Fuerza el cierre de todas las sesiones abiertas (desde sysadmin)."
  def force_close_all_open_sessions do
    import Ecto.Query
    now = DateTime.truncate(DateTime.utc_now(), :second)
    PsqlRepo.update_all(
      from(s in UserSession, where: is_nil(s.logged_out_at)),
      set: [logged_out_at: now]
    )
  end

  @doc "Lista todas las sesiones con datos del usuario, ordenadas por más recientes."
  def list_user_sessions do
    import Ecto.Query

    PsqlRepo.all(
      from s in UserSession,
        join: u in AuthUser, on: s.user_id == u.id,
        order_by: [desc: s.inserted_at],
        select: %{
          id: s.id,
          username: u.username,
          email: u.email,
          ip_address: s.ip_address,
          device_type: s.device_type,
          browser: s.browser,
          os: s.os,
          inserted_at: s.inserted_at,
          last_seen_at: s.last_seen_at,
          logged_out_at: s.logged_out_at
        }
    )
  end

  # ============================================================
  # PASSWORD RESET FUNCTIONS
  # ============================================================

  @doc """
  Inicializa la tabla ETS para códigos de reset (llamar en Application.start)
  """
  def init_reset_codes_table do
    if :ets.whereis(@reset_codes_table) == :undefined do
      :ets.new(@reset_codes_table, [:set, :public, :named_table])
    end
    :ok
  end

  @doc """
  Solicita un código de reset para el usuario (por email o username).
  """
  def request_reset(identifier) when is_binary(identifier) do
    alias Prettycore.Emails.PasswordReset, as: PasswordResetEmail

    # Buscar por email o username
    user = get_user_by_email(identifier) || get_user_by_username(identifier)

    case user do
      nil ->
        # Por seguridad, siempre retorna éxito
        {:ok, "Si el usuario existe, recibirás un código en tu email"}

      %AuthUser{} = user ->
        if user.email && user.email != "" do
          code = generate_reset_code()
          save_reset_code(user.id, code)

          Logger.info("Reset code generated for user #{user.username}")

          case PasswordResetEmail.send_reset_code(user.email, user.username, code) do
            {:ok, _} ->
              {:ok, "Si el usuario existe, recibirás un código en tu email", mask_email(user.email)}

            {:error, reason} ->
              Logger.error("Error enviando email de reset: #{inspect(reason)}")
              {:error, "No se pudo enviar el código. Intenta nuevamente."}
          end
        else
          {:error, "El usuario no tiene email registrado"}
        end
    end
  end

  @doc """
  Verifica el código y actualiza la contraseña.
  """
  def verify_and_reset(identifier, code, new_password) do
    user = get_user_by_email(identifier) || get_user_by_username(identifier)

    case user do
      nil ->
        {:error, "Usuario no encontrado"}

      %AuthUser{} = user ->
        case verify_reset_code(user.id, code) do
          :ok ->
            case change_password(user, new_password) do
              {:ok, _updated_user} ->
                delete_reset_code(user.id)
                {:ok, "Contraseña actualizada exitosamente"}

              {:error, changeset} ->
                errors = format_changeset_errors(changeset)
                {:error, errors}
            end

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Obtiene un usuario por email.
  """
  def get_user_by_email(email) when is_binary(email) do
    PsqlRepo.get_by(AuthUser, email: email)
  end

  def get_user_by_email(_), do: nil

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp generate_reset_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp save_reset_code(user_id, code) do
    init_reset_codes_table()
    expires_at = System.system_time(:second) + 30 * 60  # 30 minutos
    :ets.insert(@reset_codes_table, {user_id, code, expires_at})
    :ok
  end

  defp verify_reset_code(user_id, code) do
    init_reset_codes_table()
    now = System.system_time(:second)

    case :ets.lookup(@reset_codes_table, user_id) do
      [{^user_id, ^code, expires_at}] when expires_at > now ->
        :ok

      [{^user_id, _other_code, _}] ->
        {:error, "Código inválido"}

      [] ->
        {:error, "Código expirado o no existe"}

      _ ->
        {:error, "Código expirado"}
    end
  end

  defp delete_reset_code(user_id) do
    init_reset_codes_table()
    :ets.delete(@reset_codes_table, user_id)
    :ok
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@") do
      [name, domain] ->
        masked = if String.length(name) > 2, do: String.slice(name, 0, 2) <> "***", else: "***"
        "#{masked}@#{domain}"
      _ ->
        "***"
    end
  end

  defp mask_email(_), do: "***"

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end
end
