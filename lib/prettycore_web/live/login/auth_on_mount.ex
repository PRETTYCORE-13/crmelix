defmodule PrettycoreWeb.AuthOnMount do
  import Phoenix.LiveView, only: [redirect: 2]
  import Phoenix.Component, only: [assign: 3]

  alias Prettycore.Auth

  def on_mount(:ensure_authenticated, params, session, socket) do
    user_id = session["user_id"]
    email_from_session = session["user_email"]
    email_from_url = params["email"]

    cond do
      is_nil(user_id) or is_nil(email_from_session) ->
        {:halt, redirect(socket, to: "/")}

      not is_nil(email_from_url) and email_from_url != email_from_session ->
        {:halt, redirect(socket, to: "/admin/disenador")}

      true ->
        user_name = session["user_name"]
        user = Auth.get_user(user_id)
        role  = (user && user.role) || "user"
        perms = (user && user.permissions) || []

        if Phoenix.LiveView.connected?(socket) do
          Phoenix.PubSub.subscribe(Prettycore.PubSub, "user_sessions:#{user_id}")
        end

        my_user_id = user_id

        {:cont,
         socket
         |> Phoenix.LiveView.attach_hook(:logout_hook, :handle_info, fn
           {:logout, ^my_user_id}, sock ->
             {:halt, Phoenix.LiveView.redirect(sock, to: "/")}
           _, sock ->
             {:cont, sock}
         end)
         |> assign(:current_user_id, user_id)
         |> assign(:current_user_email, email_from_session)
         |> assign(:current_user_name, user_name)
         |> assign(:user_role, role)
         |> assign(:user_permissions, perms)}
    end
  end
end
