defmodule PrettycoreWeb.SysAdmin.ConfiguracionLive do
  use PrettycoreWeb, :live_view

  import PrettycoreWeb.SysAdminLayout

  alias Prettycore.SysAdmin

  @impl true
  def mount(_params, _session, socket) do
    config = SysAdmin.get_config()

    {:ok,
     socket
     |> assign(:current_page, "configuracion")
     |> assign(:foto, config.foto || "")
     |> assign(:saved, false)
     |> assign(:error, nil)
     |> assign(:editing_mode, false)
     |> assign(:permitir_edicion, config.permitir_edicion != false)
     |> assign(:banda_texto, config.banda_texto || "¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS")
     |> assign(:banda_color, config.banda_color || "#4f46e5")
     |> assign(:arch_scan_status, :idle)
     |> assign(:arch_scan_stats, nil)}
  end

  @impl true
  def handle_event("nav", %{"id" => "configuracion"}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("previsualizar", params, socket) do
    foto        = socket.assigns.foto
    banda_texto = String.trim(params["banda_texto"] || socket.assigns.banda_texto)
    banda_color = String.trim(params["banda_color"] || socket.assigns.banda_color)

    attrs = %{
      foto: foto,
      permitir_edicion: socket.assigns.permitir_edicion,
      banda_texto: banda_texto,
      banda_color: banda_color
    }

    case SysAdmin.save_config(attrs) do
      {:ok, _config} ->
        {:noreply,
         socket
         |> assign(:banda_texto, banda_texto)
         |> assign(:banda_color, banda_color)
         |> assign(:saved, true)
         |> assign(:error, nil)}

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
          |> Enum.join("; ")

        {:noreply, assign(socket, :error, "Error al guardar: #{errors}")}
    end
  end

  @impl true
  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, :editing_mode, !socket.assigns.editing_mode)}
  end

  @impl true
  def handle_event("toggle_permitir_edicion", _, socket) do
    {:noreply, assign(socket, :permitir_edicion, !socket.assigns.permitir_edicion)}
  end

  @impl true
  def handle_event("cancelar_edicion", _, socket) do
    config = SysAdmin.get_config()
    {:noreply,
     socket
     |> assign(:foto, config.foto || "")
     |> assign(:banda_texto, config.banda_texto || "¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS")
     |> assign(:banda_color, config.banda_color || "#4f46e5")
     |> assign(:editing_mode, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("dismiss_saved", _, socket) do
    {:noreply, assign(socket, :saved, false)}
  end

  @impl true
  def handle_event("update_banda_texto", %{"value" => texto}, socket) do
    {:noreply, assign(socket, :banda_texto, texto)}
  end

  @impl true
  def handle_event("update_banda_color", %{"banda_color" => color}, socket) do
    {:noreply, assign(socket, :banda_color, color)}
  end

  @impl true
  def handle_event("update_banda_color_hex", %{"value" => color}, socket) do
    if String.match?(color, ~r/^#[0-9a-fA-F]{6}$/) do
      {:noreply, assign(socket, :banda_color, color)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("scan_architecture", _params, socket) do
    result = Prettycore.ArchitectureScanner.scan()
    stats  = %{funcionalidades: result.funcionalidades, tablas: result.tablas}

    {:noreply,
     socket
     |> assign(:arch_scan_status, :done)
     |> assign(:arch_scan_stats, stats)}
  end

  @impl true
  def handle_event("reset_arch_status", _params, socket) do
    {:noreply, assign(socket, arch_scan_status: :idle, arch_scan_stats: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <div class="p-8 max-w-2xl">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-gray-900">Configuración del sistema</h1>
          <p class="text-sm text-gray-500 mt-1">Ajusta los parámetros de la plataforma.</p>
        </div>

        <%= if @saved do %>
          <div class="mb-6 flex items-center gap-3 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl px-4 py-3 text-sm">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            Configuración guardada correctamente.
            <button type="button" phx-click="dismiss_saved" class="ml-auto text-emerald-600 hover:text-emerald-900">✕</button>
          </div>
        <% end %>

        <%= if @error do %>
          <div class="mb-6 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
            {@error}
          </div>
        <% end %>

        <form phx-submit="previsualizar" class="bg-white rounded-2xl border border-gray-200 shadow-sm divide-y divide-gray-100">

          <!-- Banda de Publicidad -->
          <div class="p-5">
            <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Banda de Publicidad</p>

            <div class="mb-3 rounded-lg overflow-hidden">
              <div class="overflow-hidden whitespace-nowrap py-2 px-4 text-sm font-semibold text-white text-center truncate rounded-lg"
                   style={"background-color: #{@banda_color}"}>
                <%= @banda_texto %>
              </div>
            </div>

            <div class="space-y-3">
              <div>
                <label class="block text-xs font-medium text-gray-500 mb-1">Texto</label>
                <input
                  type="text"
                  name="banda_texto"
                  value={@banda_texto}
                  maxlength="200"
                  placeholder="Texto de la banda superior..."
                  phx-keyup="update_banda_texto"
                  phx-debounce="300"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 transition"
                />
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-500 mb-1">Color de fondo</label>
                <div class="flex items-center gap-3">
                  <input
                    type="color"
                    name="banda_color"
                    value={@banda_color}
                    phx-change="update_banda_color"
                    class="h-9 w-16 rounded-lg border border-gray-300 cursor-pointer p-0.5"
                  />
                  <input
                    type="text"
                    name="banda_color_hex"
                    value={@banda_color}
                    maxlength="7"
                    placeholder="#4f46e5"
                    phx-keyup="update_banda_color_hex"
                    phx-debounce="300"
                    class="w-28 text-sm font-mono rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 transition"
                  />
                  <span class="text-xs text-gray-400">Hex p. ej. #4f46e5</span>
                </div>
              </div>
            </div>
          </div>

          <div class="p-5 bg-gray-50 rounded-b-2xl flex justify-end gap-3">
            <button type="button" phx-click="cancelar_edicion"
              class="px-6 py-2 text-sm font-semibold rounded-xl border text-gray-700 bg-white border-gray-300 hover:bg-gray-100 transition-colors">
              Cancelar
            </button>
            <button type="submit"
              class="px-6 py-2 text-sm font-semibold rounded-xl bg-gray-900 text-white hover:bg-black transition-colors">
              Guardar
            </button>
          </div>
        </form>
      </div>

    </.sidebar>
    """
  end
end
