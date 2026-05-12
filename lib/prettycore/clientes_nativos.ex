defmodule Prettycore.ClientesNativos do
  @moduledoc "Gestión de clientes nativos creados directamente en PostgreSQL."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.ClientesNativos.ClienteNativo
  alias Prettycore.ClientesNativos.ClienteNativoGama

  def list_todos do
    PsqlRepo.all(from c in ClienteNativo, order_by: [desc: c.inserted_at])
  end

  def search(q) do
    words =
      q
      |> String.downcase()
      |> String.split(~r/\s+/, trim: true)
      |> Enum.map(&"%#{&1}%")

    case words do
      [] ->
        list_todos()

      _ ->
        PsqlRepo.all(
          from c in ClienteNativo,
            where: ^build_search_filter(words),
            order_by: c.nombre
        )
    end
  end

  defp build_search_filter([word | rest]) do
    base =
      dynamic(
        [c],
        ilike(c.nombre, ^word) or ilike(c.username, ^word) or
          ilike(c.email, ^word) or ilike(c.telefono, ^word)
      )

    Enum.reduce(rest, base, fn w, acc ->
      dynamic(
        [c],
        ^acc and
          (ilike(c.nombre, ^w) or ilike(c.username, ^w) or
             ilike(c.email, ^w) or ilike(c.telefono, ^w))
      )
    end)
  end

  def get(id), do: PsqlRepo.get(ClienteNativo, id)

  def get_by_username(username), do: PsqlRepo.get_by(ClienteNativo, username: username)

  def crear(attrs) do
    %ClienteNativo{}
    |> ClienteNativo.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def actualizar(%ClienteNativo{} = c, attrs) do
    c
    |> ClienteNativo.update_changeset(attrs)
    |> PsqlRepo.update()
  end

  def cambiar_password(%ClienteNativo{} = c, new_password) do
    c
    |> ClienteNativo.password_changeset(%{password: new_password})
    |> PsqlRepo.update()
  end

  @token_ttl_hours 24

  @doc "Genera un token de reset de contraseña válido por 24h y lo persiste."
  def generar_reset_token(%ClienteNativo{} = c) do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    expires_at = DateTime.utc_now() |> DateTime.add(@token_ttl_hours * 3600, :second) |> DateTime.truncate(:second)

    c
    |> Ecto.Changeset.change(reset_token: token, reset_token_expires_at: expires_at)
    |> PsqlRepo.update()
    |> case do
      {:ok, updated} -> {:ok, token, updated}
      error -> error
    end
  end

  @doc "Busca un cliente por token válido (no expirado)."
  def get_by_reset_token(token) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    PsqlRepo.one(
      from c in ClienteNativo,
        where: c.reset_token == ^token and c.reset_token_expires_at > ^now
    )
  end

  @doc "Actualiza la contraseña y limpia el token de reset."
  def consumir_reset_token(%ClienteNativo{} = c, new_password) do
    PsqlRepo.transaction(fn ->
      {:ok, updated} =
        c
        |> ClienteNativo.password_changeset(%{password: new_password})
        |> PsqlRepo.update()

      updated
      |> Ecto.Changeset.change(reset_token: nil, reset_token_expires_at: nil)
      |> PsqlRepo.update!()
    end)
  end

  def eliminar(%ClienteNativo{} = c), do: PsqlRepo.delete(c)

  def toggle_activo(%ClienteNativo{} = c) do
    c
    |> Ecto.Changeset.change(activo: !c.activo)
    |> PsqlRepo.update()
  end

  @doc "Lista los números de gama asignados a un cliente."
  def get_gamas(cliente_id) do
    PsqlRepo.all(
      from g in ClienteNativoGama,
        where: g.cliente_nativo_id == ^cliente_id,
        select: g.gama_numero,
        order_by: g.gama_numero
    )
  end

  @doc "Reemplaza las gamas asignadas al cliente (borra las anteriores e inserta las nuevas)."
  def set_gamas(cliente_id, numeros) when is_list(numeros) do
    PsqlRepo.delete_all(from g in ClienteNativoGama, where: g.cliente_nativo_id == ^cliente_id)
    Enum.each(numeros, fn n ->
      PsqlRepo.insert!(%ClienteNativoGama{cliente_nativo_id: cliente_id, gama_numero: n})
    end)
    :ok
  end

  @doc "Autentica un cliente nativo. Retorna {:ok, cliente} o {:error, :invalid_credentials}."
  def authenticate(username, password) do
    case get_by_username(username) do
      nil ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}

      %ClienteNativo{activo: false} ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}

      cliente ->
        if ClienteNativo.verify_password(cliente, password) do
          {:ok, cliente}
        else
          {:error, :invalid_credentials}
        end
    end
  end
end
