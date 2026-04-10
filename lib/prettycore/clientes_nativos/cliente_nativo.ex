defmodule Prettycore.ClientesNativos.ClienteNativo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "clientes_nativos" do
    field :nombre,        :string
    field :username,      :string
    field :email,         :string
    field :password_hash, :string
    field :password,      :string, virtual: true
    field :telefono,      :string
    field :rfc,           :string
    field :direccion,     :string
    field :notas,         :string
    field :activo,         :boolean, default: true
    field :lista_precios,  :integer, default: 1
    field :sucursal_numero, :integer

    timestamps(type: :utc_datetime)
  end

  def changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:nombre, :username, :email, :password, :telefono, :rfc, :direccion, :notas, :activo, :lista_precios, :sucursal_numero])
    |> validate_required([:nombre, :username, :password])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_length(:password, min: 6, max: 72)
    |> validate_length(:nombre, min: 2, max: 255)
    |> validate_exclusion(:username, ~w(admin sysadmin administrador root superuser),
        message: "ese nombre de usuario no está permitido")
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> hash_password()
  end

  def update_changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:nombre, :email, :telefono, :rfc, :direccion, :notas, :activo, :lista_precios, :sucursal_numero])
    |> validate_required([:nombre])
    |> validate_length(:nombre, min: 2, max: 255)
    |> unique_constraint(:email)
  end

  def password_changeset(cliente, attrs) do
    cliente
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 6, max: 72)
    |> hash_password()
  end

  defp hash_password(changeset) do
    case get_change(changeset, :password) do
      nil      -> changeset
      password ->
        hash = Pbkdf2.hash_pwd_salt(password)
        put_change(changeset, :password_hash, hash)
    end
  end

  def verify_password(%__MODULE__{password_hash: nil}, _password) do
    Pbkdf2.no_user_verify()
    false
  end

  def verify_password(%__MODULE__{password_hash: hash}, password) when is_binary(password) do
    Pbkdf2.verify_pass(password, hash)
  end

  def verify_password(_, _), do: false
end
