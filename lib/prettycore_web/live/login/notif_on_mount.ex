defmodule PrettycoreWeb.NotifOnMount do
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, _session, socket) do
    socket = assign(socket, :notif_refresh, 0)
    user_id = socket.assigns[:current_user_id]

    if user_id && connected?(socket) do
      Phoenix.PubSub.subscribe(Prettycore.PubSub, "notif:#{user_id}")

      socket =
        attach_hook(socket, :notif_info, :handle_info, fn
          {:notif_nueva, _notif}, sock ->
            {:halt, update(sock, :notif_refresh, &(&1 + 1))}

          _other, sock ->
            {:cont, sock}
        end)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end
end
