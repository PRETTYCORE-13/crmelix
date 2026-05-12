defmodule PrettycoreWeb.ResetPasswordClienteLive do
  use PrettycoreWeb, :live_view

  alias Prettycore.ClientesNativos

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case ClientesNativos.get_by_reset_token(token) do
      nil ->
        {:ok,
         socket
         |> assign(token_valido: false, cliente: nil, token: token,
                   pw: "", pw2: "", error: nil, exito: false)}

      cliente ->
        {:ok,
         socket
         |> assign(token_valido: true, cliente: cliente, token: token,
                   pw: "", pw2: "", error: nil, exito: false)}
    end
  end

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
    <div class="min-h-screen bg-gradient-to-br from-violet-50 to-indigo-100 flex items-center justify-center px-4">
      <div class="w-full max-w-md">

        <!-- Logo -->
        <div class="text-center mb-8">
          <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-br from-violet-600 to-indigo-600 shadow-lg mb-4">
            <svg class="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
            </svg>
          </div>
          <h1 class="text-2xl font-bold text-gray-900">PrettyCore</h1>
        </div>

        <div class="bg-white rounded-2xl shadow-xl p-8">

          <%= if @exito do %>
            <!-- Éxito -->
            <div class="text-center">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-green-100 mb-4">
                <svg class="w-8 h-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <h2 class="text-xl font-bold text-gray-900 mb-2">¡Contraseña actualizada!</h2>
              <p class="text-gray-500 text-sm mb-6">Ya puedes iniciar sesión con tu nueva contraseña.</p>
              <a href="/" class="inline-block bg-gradient-to-r from-violet-600 to-indigo-600 text-white font-semibold px-6 py-3 rounded-xl hover:opacity-90 transition-opacity">
                Ir al inicio de sesión
              </a>
            </div>
          <% else %>
            <%= if not @token_valido do %>
              <!-- Token inválido -->
              <div class="text-center">
                <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-100 mb-4">
                  <svg class="w-8 h-8 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <h2 class="text-xl font-bold text-gray-900 mb-2">Enlace inválido o expirado</h2>
                <p class="text-gray-500 text-sm">Este enlace de restablecimiento ya no es válido. Solicita uno nuevo a tu administrador.</p>
              </div>
            <% else %>
              <!-- Formulario -->
              <h2 class="text-xl font-bold text-gray-900 mb-1">Nueva contraseña</h2>
              <p class="text-sm text-gray-500 mb-6">
                Hola <strong><%= @cliente.nombre %></strong>, elige una contraseña segura.
              </p>

              <%= if @error do %>
                <div class="mb-4 flex items-center gap-2 bg-red-50 border border-red-200 text-red-700 text-sm rounded-xl px-4 py-3">
                  <svg class="w-4 h-4 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01" />
                  </svg>
                  <%= @error %>
                </div>
              <% end %>

              <form phx-submit="cambiar" class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Nueva contraseña</label>
                  <input
                    type="password"
                    name="pw"
                    value={@pw}
                    required
                    minlength="6"
                    placeholder="Mínimo 6 caracteres"
                    class="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent text-gray-900 text-sm"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Confirmar contraseña</label>
                  <input
                    type="password"
                    name="pw2"
                    value={@pw2}
                    required
                    minlength="6"
                    placeholder="Repite la contraseña"
                    class="w-full px-4 py-3 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent text-gray-900 text-sm"
                  />
                </div>
                <button
                  type="submit"
                  class="w-full bg-gradient-to-r from-violet-600 to-indigo-600 text-white font-semibold py-3 rounded-xl hover:opacity-90 transition-opacity text-sm">
                  Guardar contraseña
                </button>
              </form>
            <% end %>
          <% end %>

        </div>
      </div>
    </div>
    """
  end
end
