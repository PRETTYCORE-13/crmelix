defmodule PrettycoreWeb.AuthOnMount do
  import Phoenix.LiveView, only: [redirect: 2]
  import Phoenix.Component, only: [assign: 3]

  alias Prettycore.Auth
  alias Prettycore.ClientesNativos
  alias Prettycore.SysAdmin

  def on_mount(:ensure_authenticated, params, session, socket) do
    user_id = session["user_id"]
    email_from_session = session["user_email"]
    email_from_url = params["email"]
    session_role = session["role"]

    cond do
      # Sin sesión → fuera
      is_nil(user_id) or is_nil(email_from_session) ->
        {:halt, redirect(socket, to: "/")}

      # El email en URL no coincide → lo mandamos a SU ruta correcta
      not is_nil(email_from_url) and email_from_url != email_from_session ->
        correct_path = "/admin/platform/#{email_from_session}"
        {:halt, redirect(socket, to: correct_path)}

      true ->
        frog_token   = session["frog_token"]
        company_logo = get_company_logo(frog_token)
        user_name    = session["user_name"]
        modo_nativo  = SysAdmin.get_config().modo_nativo == true

        {user_role, user_permissions, lista_precios, sucursal_numero} =
          if session_role == "cliente_nativo" do
            cliente = ClientesNativos.get(user_id)
            lp  = (cliente && cliente.lista_precios)  || 1
            suc = (cliente && cliente.sucursal_numero)
            {"cliente_nativo", ["inicio", "tienda"], lp, suc}
          else
            user = Auth.get_user(user_id)
            role  = (user && user.role) || "user"
            perms = (user && user.permissions) || ["inicio"]
            {role, perms, nil, nil}
          end

        {:cont,
         socket
         |> assign(:current_user_id, user_id)
         |> assign(:current_user_email, email_from_session)
         |> assign(:current_user_name, user_name)
         |> assign(:company_logo, company_logo)
         |> assign(:frog_token, frog_token)
         |> assign(:user_role, user_role)
         |> assign(:user_permissions, user_permissions)
         |> assign(:lista_precios, lista_precios)
         |> assign(:sucursal_numero, sucursal_numero)
         |> assign(:modo_nativo, modo_nativo)}
    end
  end

  defp get_company_logo(_token) do
    :persistent_term.get(:company_logo_cache, nil)
  end
end
