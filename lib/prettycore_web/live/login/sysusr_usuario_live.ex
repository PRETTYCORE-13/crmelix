# lib/prettycore_web/live/login_live.ex
defmodule PrettycoreWeb.LoginLive do
  use PrettycoreWeb, :live_view

  def mount(_params, session, socket) do
    # Si ya hay sesión activa, redirigir al panel correspondiente
    if session["user_id"] do
      redirect_to = if session["role"] == "sysadmin", do: "/sysadmin", else: "/admin/platform"
      {:ok, push_navigate(socket, to: redirect_to)}
    else
      {:ok,
       socket
       |> assign(:username, "")
       |> assign(:password, "")
       |> assign(:error, nil)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-6 bg-gradient-to-b from-purple-950 via-slate-950 to-black">
      <div class="w-full max-w-md p-9 rounded-2xl bg-slate-950/95 border border-purple-600/35 shadow-2xl shadow-purple-500/20 backdrop-blur-xl">
        <div class="text-center mb-7">
          <h1 class="text-2xl font-semibold text-gray-50 tracking-wide mb-1.5">Iniciar sesión</h1>

          <p class="text-sm text-gray-400">Accede al sistema</p>
        </div>

        <%= if Phoenix.Flash.get(@flash, :error) do %>
          <div class="mb-4 p-3 bg-red-500/10 border border-red-500/30 rounded-lg text-red-300 text-sm text-center">
            {Phoenix.Flash.get(@flash, :error)}
          </div>
        <% end %>

        <form class="flex flex-col gap-4" action={~p"/"} method="post">
          <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
          <.input
            type="text"
            id="username"
            name="username"
            label="Usuario (correo)"
            value={@username}
            maxlength="100"
            class="w-full px-3.5 py-2.5 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-500 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 focus:shadow-lg focus:shadow-purple-900/50 transition-all"
          />
          <.input
            type="password"
            id="password"
            name="password"
            label="Contraseña"
            value={@password}
            maxlength="72"
            class="w-full px-3.5 py-2.5 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-500 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 focus:shadow-lg focus:shadow-purple-900/50 transition-all"
          />
          <.button
            type="submit"
            class="w-full mt-2 px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/50 hover:brightness-110 hover:shadow-xl hover:shadow-purple-600/60 active:shadow-md transition-all"
          >
            Entrar
          </.button>
          <div class="mt-4 text-center">
            <.link
              navigate={~p"/password-reset"}
              class="text-sm text-purple-500 hover:text-purple-300 hover:shadow-sm transition-all"
            >
              ¿Olvidaste tu contraseña?
            </.link>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
