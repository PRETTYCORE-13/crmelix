defmodule Prettycore.Notificaciones do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Notificaciones.Notificacion

  @doc "Crea una notificación y la transmite por PubSub al usuario."
  def crear(user_id, attrs) when is_binary(user_id) do
    attrs = Map.merge(%{"tipo" => "info"}, stringify_keys(attrs))
    attrs = Map.put(attrs, "user_id", user_id)

    case %Notificacion{} |> Notificacion.changeset(attrs) |> Repo.insert() do
      {:ok, notif} = ok ->
        Phoenix.PubSub.broadcast(Prettycore.PubSub, "notif:#{user_id}", {:notif_nueva, notif})
        ok
      error ->
        error
    end
  end

  def crear(nil, _attrs), do: {:error, :no_user}

  @doc "Últimas N notificaciones de un usuario."
  def list_recientes(user_id, limit \\ 25) do
    Repo.all(
      from n in Notificacion,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit
    )
  end

  @doc "Cantidad de notificaciones no leídas."
  def count_no_leidas(user_id) do
    Repo.one(
      from n in Notificacion,
        where: n.user_id == ^user_id and n.leida == false,
        select: count(n.id)
    ) || 0
  end

  @doc "Marca una notificación como leída."
  def marcar_leida(id) do
    case Repo.get(Notificacion, id) do
      nil -> :ok
      n   -> n |> Notificacion.changeset(%{"leida" => true}) |> Repo.update()
    end
  end

  @doc "Marca todas las notificaciones del usuario como leídas."
  def marcar_todas_leidas(user_id) do
    Repo.update_all(
      from(n in Notificacion, where: n.user_id == ^user_id and n.leida == false),
      set: [leida: true]
    )
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
