defmodule Prettycore.Auth.AuthUser do
  @moduledoc """
  Schema de usuario para autenticación con PostgreSQL.
  Usa Bcrypt para hashing seguro de contraseñas.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :active, :boolean, default: true
    field :role, :string, default: "user"
    field :usuario_frog, :string
    field :permissions, {:array, :string}, default: ["inicio", "tienda", "pedidos"]
    field :cliente_codigo, :string
    field :dir_codigo, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset para crear un nuevo usuario.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :active, :role, :usuario_frog, :cliente_codigo, :dir_codigo])
    |> validate_required([:username, :password])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 6, max: 72, message: "debe tener entre 6 y 72 caracteres")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe ser un email valido")
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> hash_password()
  end

  @doc """
  Changeset para admin/oficina: todos los campos son obligatorios.
  """
  def admin_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :active, :role, :usuario_frog, :cliente_codigo, :dir_codigo])
    |> validate_required([:username, :password, :email, :cliente_codigo, :dir_codigo],
        message: "es obligatorio")
    |> validate_length(:dir_codigo, min: 1, message: "es obligatorio")
    |> validate_length(:cliente_codigo, min: 1, message: "es obligatorio")
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 6, max: 72, message: "debe tener entre 6 y 72 caracteres")
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe ser un email valido")
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> hash_password()
  end

  @doc """
  Changeset para actualizar usuario (sin cambiar password).
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :active, :role, :usuario_frog, :permissions, :cliente_codigo, :dir_codigo])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe ser un email valido")
    |> unique_constraint(:email)
  end

  @doc """
  Changeset para cambiar password.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72, message: "debe tener entre 6 y 72 caracteres")
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        # PBKDF2-SHA512 con 160,000 iteraciones (OWASP recomendado)
        hash = Pbkdf2.hash_pwd_salt(password)
        put_change(changeset, :password_hash, hash)
    end
  end

  @doc """
  Verifica si el password coincide usando PBKDF2.
  Incluye proteccion contra timing attacks.
  """
  def verify_password(%__MODULE__{password_hash: nil}, _password) do
    # Simula tiempo de verificacion para evitar timing attacks
    Pbkdf2.no_user_verify()
    false
  end

  def verify_password(%__MODULE__{password_hash: hash}, password) when is_binary(password) do
    Pbkdf2.verify_pass(password, hash)
  end

  def verify_password(_, _), do: false
end
