defmodule PrettycoreWeb.ResetPasswordClienteLive do
  use PrettycoreWeb, :live_view

  alias Prettycore.ClientesNativos

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case ClientesNativos.get_by_reset_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Enlace inválido · PrettyCore")
         |> assign(token_valido: false, cliente: nil, token: token,
                   pw: "", pw2: "", error: nil, exito: false,
                   show_pw: false, show_pw2: false)}

      cliente ->
        {:ok,
         socket
         |> assign(page_title: "Nueva contraseña · PrettyCore")
         |> assign(token_valido: true, cliente: cliente, token: token,
                   pw: "", pw2: "", error: nil, exito: false,
                   show_pw: false, show_pw2: false)}
    end
  end

  @impl true
  def handle_event("toggle_show_pw", _, socket),
    do: {:noreply, assign(socket, show_pw: !socket.assigns.show_pw)}

  def handle_event("toggle_show_pw2", _, socket),
    do: {:noreply, assign(socket, show_pw2: !socket.assigns.show_pw2)}

  @impl true
  def handle_event("cambiar", %{"pw" => pw, "pw2" => pw2}, socket) do
    cond do
      String.length(pw) < 6 ->
        {:noreply, assign(socket, error: "La contraseña debe tener al menos 6 caracteres", pw: pw, pw2: pw2)}

      pw != pw2 ->
        {:noreply, assign(socket, error: "Las contraseñas no coinciden", pw: pw, pw2: pw2)}

      true ->
        case ClientesNativos.get_by_reset_token(socket.assigns.token) do
          nil ->
            {:noreply, assign(socket, error: "El enlace ha expirado o ya fue utilizado", token_valido: false)}

          cliente ->
            case ClientesNativos.consumir_reset_token(cliente, pw) do
              {:ok, _} ->
                {:noreply, assign(socket, exito: true, error: nil)}

              _ ->
                {:noreply, assign(socket, error: "Ocurrió un error. Intenta de nuevo.")}
            end
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center p-6 bg-gradient-to-b from-purple-950 via-slate-950 to-black">

      <!-- Decoración de fondo -->
      <div class="pointer-events-none fixed inset-0 overflow-hidden" aria-hidden="true">
        <div class="absolute -top-40 -right-40 w-96 h-96 rounded-full bg-purple-700/10 blur-3xl"></div>
        <div class="absolute -bottom-40 -left-40 w-96 h-96 rounded-full bg-indigo-700/10 blur-3xl"></div>
      </div>

      <div class="relative w-full max-w-md">

        <!-- Logo / Brand -->
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

          <%= if @exito do %>
            <!-- ── Estado: Éxito ─────────────────────────────── -->
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-green-500/15 border border-green-500/30 mb-5">
                <svg class="w-8 h-8 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 class="text-xl font-semibold text-gray-50 mb-2">¡Contraseña actualizada!</h2>
              <p class="text-gray-400 text-sm mb-7 leading-relaxed">
                Tu contraseña ha sido cambiada exitosamente.<br>Ya puedes iniciar sesión.
              </p>
              <a href="/"
                class="inline-block w-full text-center px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/40 hover:brightness-110 hover:shadow-xl hover:shadow-purple-600/50 active:shadow-md transition-all">
                Ir al inicio de sesión
              </a>
            </div>

          <% else %>
            <%= if not @token_valido do %>
              <!-- ── Estado: Token inválido ──────────────────── -->
              <div class="text-center">
                <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-500/15 border border-red-500/30 mb-5">
                  <svg class="w-8 h-8 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h2 class="text-xl font-semibold text-gray-50 mb-2">Enlace inválido o expirado</h2>
                <p class="text-gray-400 text-sm leading-relaxed">
                  Este enlace ya no es válido o ha expirado.<br>
                  Solicita uno nuevo a tu administrador.
                </p>
              </div>

            <% else %>
              <!-- ── Estado: Formulario ──────────────────────── -->
              <div class="text-center mb-7">
                <h2 class="text-2xl font-semibold text-gray-50 tracking-wide mb-1.5">Nueva contraseña</h2>
                <p class="text-sm text-gray-400">
                  Hola, <span class="text-purple-400 font-medium"><%= @cliente.nombre %></span>
                </p>
              </div>

              <%= if @error do %>
                <div class="mb-5 flex items-center gap-2.5 bg-red-500/10 border border-red-500/30 rounded-lg px-4 py-3 text-red-300 text-sm">
                  <svg class="w-4 h-4 shrink-0 text-red-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01" />
                  </svg>
                  <%= @error %>
                </div>
              <% end %>

              <form phx-submit="cambiar" class="flex flex-col gap-4">

                <!-- Campo: Nueva contraseña -->
                <div>
                  <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">
                    Nueva contraseña
                  </label>
                  <div class="relative">
                    <input
                      type={if @show_pw, do: "text", else: "password"}
                      name="pw"
                      value={@pw}
                      required
                      minlength="6"
                      placeholder="Mínimo 6 caracteres"
                      autocomplete="new-password"
                      class="w-full px-3.5 py-2.5 pr-11 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 focus:shadow-lg focus:shadow-purple-900/50 transition-all"
                    />
                    <button
                      type="button"
                      phx-click="toggle_show_pw"
                      tabindex="-1"
                      class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors">
                      <%= if @show_pw do %>
                        <svg class="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                        </svg>
                      <% else %>
                        <svg class="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        </svg>
                      <% end %>
                    </button>
                  </div>
                </div>

                <!-- Campo: Confirmar contraseña -->
                <div>
                  <label class="block text-xs font-medium text-gray-400 mb-1.5 uppercase tracking-wide">
                    Confirmar contraseña
                  </label>
                  <div class="relative">
                    <input
                      type={if @show_pw2, do: "text", else: "password"}
                      name="pw2"
                      value={@pw2}
                      required
                      minlength="6"
                      placeholder="Repite la contraseña"
                      autocomplete="new-password"
                      class="w-full px-3.5 py-2.5 pr-11 rounded-lg border border-gray-800 bg-slate-950 text-gray-50 text-sm placeholder:text-gray-600 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500/50 focus:shadow-lg focus:shadow-purple-900/50 transition-all"
                    />
                    <button
                      type="button"
                      phx-click="toggle_show_pw2"
                      tabindex="-1"
                      class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors">
                      <%= if @show_pw2 do %>
                        <svg class="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                        </svg>
                      <% else %>
                        <svg class="w-4.5 h-4.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        </svg>
                      <% end %>
                    </button>
                  </div>
                </div>

                <button
                  type="submit"
                  class="w-full mt-2 px-5 py-2.5 rounded-lg bg-gradient-to-br from-purple-500 via-purple-600 to-purple-900 text-gray-50 text-sm font-medium border border-purple-500/70 shadow-lg shadow-purple-600/50 hover:brightness-110 hover:shadow-xl hover:shadow-purple-600/60 active:shadow-md transition-all">
                  Guardar contraseña
                </button>

              </form>
            <% end %>
          <% end %>

        </div>

        <!-- Footer -->
        <p class="text-center text-xs text-gray-600 mt-6">
          &copy; <%= DateTime.utc_now().year %> PrettyCore. Todos los derechos reservados.
        </p>

      </div>
    </div>
    """
  end
end
