defmodule PrettycoreWeb.SysAdminAuthOnMount do
  import Phoenix.LiveView, only: [redirect: 2]
  import Phoenix.Component, only: [assign: 3]

  def on_mount(:ensure_sysadmin, _params, session, socket) do
    user_id = session["user_id"]
    user_name = session["user_name"]
    role = session["role"]

    cond do
      is_nil(user_id) ->
        {:halt, redirect(socket, to: "/")}

      role != "sysadmin" ->
        {:halt, redirect(socket, to: "/")}

      true ->
        {:cont,
         socket
         |> assign(:current_user_id, user_id)
         |> assign(:current_user_name, user_name)
         |> assign(:user_role, "sysadmin")
         |> assign(:user_permissions, [])}
    end
  end
end
