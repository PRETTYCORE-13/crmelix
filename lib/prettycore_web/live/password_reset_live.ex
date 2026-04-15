# apps/prettycore_web/lib/prettycore_web/live/password_reset_live.ex
defmodule PrettycoreWeb.PasswordResetLive do
  use PrettycoreWeb, :live_view
  alias Prettycore.Auth

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:step, :request)
     # <- Cambiar de email a username
     |> assign(:username, "")
     |> assign(:masked_email, nil)
     |> assign(:code, "")
     |> assign(:new_password, "")
     |> assign(:confirm_password, "")
     |> assign(:message, nil)
     |> assign(:error, nil)
     |> assign(:loading, false)}
  end

  @impl true
  def handle_event("request_code", %{"username" => username}, socket) do
    socket = assign(socket, :loading, true)

    case Auth.request_reset(username) do
      {:ok, message, masked_email} ->
        {:noreply,
         socket
         |> assign(:step, :verify)
         |> assign(:username, username)
         |> assign(:masked_email, masked_email)
         |> assign(:message, message)
         |> assign(:error, nil)
         |> assign(:loading, false)}

      {:ok, message} ->
        {:noreply,
         socket
         |> assign(:step, :verify)
         |> assign(:username, username)
         |> assign(:masked_email, "***")
         |> assign(:message, message)
         |> assign(:error, nil)
         |> assign(:loading, false)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:error, "Lo sentimos, este usuario es incorrecto.")
         |> assign(:message, nil)
         |> assign(:loading, false)}

      {:error, :inactive} ->
        {:noreply,
         socket
         |> assign(:error, "Lo sentimos, este usuario se encuentra inactivo.")
         |> assign(:message, nil)
         |> assign(:loading, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:error, to_string(reason))
         |> assign(:message, nil)
         |> assign(:loading, false)}
    end
  end

  @impl true
  def handle_event(
        "verify_code",
        %{"code" => code, "new_password" => password, "confirm_password" => confirm},
        socket
      ) do
    socket = assign(socket, :loading, true)

    cond do
      password != confirm ->
        {:noreply, assign(socket, error: "Las contraseñas no coinciden", loading: false)}

      String.length(password) < 8 ->
        {:noreply,
         assign(socket, error: "La contraseña debe tener al menos 8 caracteres", loading: false)}

      true ->
        # Usar username en lugar de email
        case Auth.verify_and_reset(socket.assigns.username, code, password) do
          {:ok, message} ->
            {:noreply,
             socket
             |> assign(:step, :success)
             |> assign(:message, message)
             |> assign(:error, nil)
             |> assign(:loading, false)}

          {:error, reason} ->
            {:noreply, assign(socket, error: to_string(reason), loading: false)}
        end
    end
  end

  @impl true
  def handle_event("back_to_request", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :request)
     |> assign(:code, "")
     |> assign(:new_password, "")
     |> assign(:confirm_password, "")
     |> assign(:message, nil)
     |> assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gradient-to-br from-purple-600 via-slate-900 to-slate-950 p-4">
      <div class="w-full max-w-md bg-white rounded-2xl shadow-2xl p-8">
        <div class="text-center mb-8">
          <h1 class="text-2xl font-bold text-gray-900 mb-2">Cambio de Contraseña</h1>

          <p class="text-sm text-gray-500">Recupera el acceso a tu cuenta</p>
        </div>

        <%= if @message do %>
          <div class="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg text-green-800 text-sm">
            {@message}
          </div>
        <% end %>

        <%= if @error do %>
          <div class="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg text-red-800 text-sm">
            {@error}
          </div>
        <% end %>

        <%= if @step == :request do %>
          <form id="request-form" phx-submit="request_code" class="space-y-6">
            <div class="space-y-2">
              <label for="username" class="block text-sm font-medium text-gray-700">Usuario</label>
              <input
                id="username"
                name="username"
                type="text"
                required
                maxlength="50"
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all outline-none"
              />
            </div>

            <button
              type="submit"
              disabled={@loading}
              class="w-full px-4 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-lg font-medium hover:from-purple-700 hover:to-purple-800 transition-all shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {if @loading, do: "Enviando...", else: "Enviar código"}
            </button>
          </form>
        <% end %>

        <%= if @step == :verify do %>
          <form id="verify-form" phx-submit="verify_code" class="space-y-6">
            <div class="space-y-2">
              <label for="code" class="block text-sm font-medium text-gray-700">
                Código de verificación
              </label>
              <input
                id="code"
                name="code"
                type="text"
                value={@code}
                maxlength="6"
                required
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg text-center text-2xl font-mono tracking-widest focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all outline-none"
                placeholder="123456"
              />
              <p class="text-xs text-gray-500 mt-1">Revisa tu correo ({@masked_email})</p>
            </div>

            <div class="space-y-2">
              <label for="new_password" class="block text-sm font-medium text-gray-700">
                Nueva contraseña
              </label>
              <input
                id="new_password"
                name="new_password"
                type="password"
                minlength="8"
                maxlength="72"
                required
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all outline-none"
              />
            </div>

            <div class="space-y-2">
              <label for="confirm_password" class="block text-sm font-medium text-gray-700">
                Confirmar contraseña
              </label>
              <input
                id="confirm_password"
                name="confirm_password"
                type="password"
                minlength="8"
                maxlength="72"
                required
                class="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent transition-all outline-none"
              />
            </div>

            <div class="flex flex-col gap-3">
              <button
                type="submit"
                disabled={@loading}
                class="px-4 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-lg font-medium hover:from-purple-700 hover:to-purple-800 transition-all shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {if @loading, do: "Verificando...", else: "Cambiar contraseña"}
              </button>
              <button
                type="button"
                phx-click="back_to_request"
                class="px-4 py-2.5 bg-white border border-gray-300 text-gray-700 rounded-lg font-medium hover:bg-gray-50 transition-all"
              >
                Nuevo código
              </button>
            </div>
          </form>
        <% end %>

        <%= if @step == :success do %>
          <div class="text-center space-y-6">
            <div class="mx-auto w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
              <svg
                class="w-8 h-8 text-green-600"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M5 13l4 4L19 7"
                />
              </svg>
            </div>

            <h2 class="text-xl font-semibold text-gray-900">¡Contraseña actualizada!</h2>

            <p class="text-sm text-gray-600">Ya puedes iniciar sesión con tu nueva contraseña.</p>

            <a
              href={~p"/"}
              class="inline-block w-full px-4 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-lg font-medium hover:from-purple-700 hover:to-purple-800 transition-all shadow-md hover:shadow-lg"
            >
              Ir a Login
            </a>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
