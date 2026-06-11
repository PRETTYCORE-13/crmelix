defmodule PrettycoreWeb.PasswordResetLive do
  use PrettycoreWeb, :live_view

  alias Prettycore.Auth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Recuperar contraseña · PrettyCore")
     |> assign(step: :request, username: "", masked_email: nil,
               code: "", new_password: "", confirm_password: "",
               message: nil, error: nil, loading: false,
               show_pw: false, show_pw2: false)}
  end

  @impl true
  def handle_event("toggle_show_pw", _, socket),
    do: {:noreply, assign(socket, show_pw: !socket.assigns.show_pw)}

  def handle_event("toggle_show_pw2", _, socket),
    do: {:noreply, assign(socket, show_pw2: !socket.assigns.show_pw2)}

  @impl true
  def handle_event("request_code", %{"username" => username}, socket) do
    username = String.trim(username)
    socket = assign(socket, loading: true, error: nil)

    case Auth.request_reset(username) do
      {:ok, _message, masked_email} ->
        {:noreply,
         socket
         |> assign(loading: false, step: :verify,
                   username: username, masked_email: masked_email)}

      {:ok, _message} ->
        {:noreply,
         socket
         |> assign(loading: false, step: :verify,
                   username: username, masked_email: "tu correo")}

      {:error, :not_found} ->
        {:noreply, assign(socket, loading: false, error: "Usuario no encontrado.")}

      {:error, :inactive} ->
        {:noreply, assign(socket, loading: false, error: "Esta cuenta está inactiva.")}

      {:error, reason} ->
        {:noreply, assign(socket, loading: false, error: to_string(reason))}
    end
  end

  @impl true
  def handle_event("verify_code", %{"code" => code, "new_password" => pw, "confirm_password" => cpw}, socket) do
    socket = assign(socket, loading: true)

    cond do
      String.length(pw) < 8 ->
        {:noreply, assign(socket, loading: false, error: "La contraseña debe tener al menos 8 caracteres.")}

      pw != cpw ->
        {:noreply, assign(socket, loading: false, error: "Las contraseñas no coinciden.")}

      true ->
        case Auth.verify_and_reset(socket.assigns.username, code, pw) do
          {:ok, _} ->
            {:noreply, assign(socket, loading: false, step: :success, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, loading: false, error: to_string(reason))}
        end
    end
  end

  @impl true
  def handle_event("back", _, socket) do
    {:noreply, assign(socket, step: :request, error: nil, username: "", code: "")}
  end

  defp mask_email(email) when is_binary(email) do
    case String.split(email, "@") do
      [name, domain] ->
        prefix = if String.length(name) > 2, do: String.slice(name, 0, 2) <> "***", else: "***"
        "#{prefix}@#{domain}"
      _ -> "***"
    end
  end
  defp mask_email(_), do: "***"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-6 bg-gradient-to-b from-purple-950 via-slate-950 to-black">

      <!-- Fondo decorativo -->
      <div class="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden="true">
        <div class="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-purple-700/10 blur-3xl"></div>
        <div class="absolute -bottom-40 -left-40 w-96 h-96 rounded-full bg-indigo-700/10 blur-3xl"></div>
      </div>

      <div class="relative w-full max-w-md">

        <!-- Brand -->
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 shadow-lg shadow-purple-600/40 mb-4">
            <svg class="w-7 h-7 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
            </svg>
          </div>
          <p class="text-sm text-purple-400 tracking-widest font-medium uppercase">PrettyCore</p>
        </div>

        <!-- Card -->
        <div class="w-full p-8 rounded-2xl bg-slate-950/95 border border-purple-600/35 shadow-2xl shadow-purple-500/20 backdrop-blur-xl">

          <%= if @step == :request do %>
            <!-- ── Paso 1: Ingresar usuario ─────────────────── -->
            <div class="text-center mb-7">
              <h2 class="text-2xl font-semibold text-gray-50 tracking-wide mb-1.5">Recuperar contraseña</h2>
              <p class="text-sm text-gray-400">Ingresa tu usuario y te enviaremos instrucciones</p>
            </div>

            <%= if @error do %>
              <div class="mb-5 flex items-center gap-2.5 bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-3 text-red-300 text-sm">
                <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01" />
                </svg>
                <%= @error %>
              </div>
            <% end %>

            <form phx-submit="request_code" class="flex flex-col gap-4">
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">Usuario</label>
                <input
                  type="text"
                  name="username"
                  value={@username}
                  required
                  maxlength="50"
                  placeholder="Tu nombre de usuario"
                  autocomplete="username"
                  class="w-full px-3.5 py-2.5 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 focus:shadow-lg focus:shadow-purple-900/50 transition-all"
                />
              </div>
              <button
                type="submit"
                disabled={@loading}
                class="w-full mt-2 px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/50 hover:brightness-110 hover:shadow-xl hover:shadow-purple-600/60 disabled:opacity-50 disabled:cursor-not-allowed active:shadow-md transition-all">
                <%= if @loading, do: "Enviando...", else: "Enviar instrucciones" %>
              </button>
            </form>

            <div class="mt-6 text-center">
              <a href="/" class="text-sm text-purple-500 hover:text-purple-300 transition-colors">
                ← Volver al inicio de sesión
              </a>
            </div>

          <% end %>

          <%= if @step == :verify do %>
            <!-- ── Paso 2: Código + nueva contraseña (admin) ── -->
            <div class="text-center mb-7">
              <h2 class="text-2xl font-semibold text-gray-50 tracking-wide mb-1.5">Verificar código</h2>
              <p class="text-sm text-gray-400">
                Enviamos un código a <span class="text-purple-400"><%= @masked_email %></span>
              </p>
            </div>

            <%= if @error do %>
              <div class="mb-5 flex items-center gap-2.5 bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-3 text-red-300 text-sm">
                <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01" />
                </svg>
                <%= @error %>
              </div>
            <% end %>

            <form phx-submit="verify_code" class="flex flex-col gap-4">
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">Código de verificación</label>
                <input
                  type="text"
                  name="code"
                  value={@code}
                  required
                  maxlength="6"
                  placeholder="123456"
                  autocomplete="one-time-code"
                  class="w-full px-3.5 py-2.5 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm text-center tracking-[0.5em] font-mono placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 transition-all"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">Nueva contraseña</label>
                <div class="relative">
                  <input
                    type={if @show_pw, do: "text", else: "password"}
                    name="new_password"
                    required
                    minlength="8"
                    maxlength="72"
                    placeholder="Mínimo 8 caracteres"
                    autocomplete="new-password"
                    class="w-full px-3.5 py-2.5 pr-11 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 transition-all"
                  />
                  <button type="button" phx-click="toggle_show_pw" tabindex="-1"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors">
                    <%= if @show_pw do %>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    <% end %>
                  </button>
                </div>
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">Confirmar contraseña</label>
                <div class="relative">
                  <input
                    type={if @show_pw2, do: "text", else: "password"}
                    name="confirm_password"
                    required
                    minlength="8"
                    maxlength="72"
                    placeholder="Repite la contraseña"
                    autocomplete="new-password"
                    class="w-full px-3.5 py-2.5 pr-11 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 transition-all"
                  />
                  <button type="button" phx-click="toggle_show_pw2" tabindex="-1"
                    class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors">
                    <%= if @show_pw2 do %>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" /></svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    <% end %>
                  </button>
                </div>
              </div>
              <button
                type="submit"
                disabled={@loading}
                class="w-full mt-2 px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/50 hover:brightness-110 disabled:opacity-50 disabled:cursor-not-allowed transition-all">
                <%= if @loading, do: "Verificando...", else: "Cambiar contraseña" %>
              </button>
            </form>

            <div class="mt-5 text-center">
              <button type="button" phx-click="back"
                class="text-sm text-purple-500 hover:text-purple-300 transition-colors">
                ← Volver
              </button>
            </div>

          <% end %>

          <%= if @step == :success do %>
            <!-- ── Éxito ──────────────────────────────────────── -->
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-green-500/15 border border-green-500/30 mb-5">
                <svg class="w-8 h-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 class="text-xl font-semibold text-gray-50 mb-2">¡Contraseña actualizada!</h2>
              <p class="text-gray-400 text-sm mb-7 leading-relaxed">
                Ya puedes iniciar sesión con tu nueva contraseña.
              </p>
              <a href="/"
                class="inline-block w-full text-center px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/40 hover:brightness-110 transition-all">
                Ir al inicio de sesión
              </a>
            </div>
          <% end %>

        </div>

        <p class="text-center text-xs text-gray-600 mt-6">
          &copy; <%= DateTime.utc_now().year %> PrettyCore. Todos los derechos reservados.
        </p>

      </div>
    </div>
    """
  end
end
