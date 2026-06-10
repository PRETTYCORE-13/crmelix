defmodule PrettycoreWeb.ConfiguracionLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.SysAdmin
  alias PrettycoreWeb.AdminNav

  @timezones [
    {"América/México - Ciudad de México (UTC-6/-5)",  "America/Mexico_City"},
    {"América/México - Monterrey (UTC-6/-5)",          "America/Monterrey"},
    {"América/México - Guadalajara (UTC-6/-5)",        "America/Guadalajara"},
    {"América/México - Cancún (UTC-5)",                "America/Cancun"},
    {"América/México - Chihuahua (UTC-7/-6)",          "America/Chihuahua"},
    {"América/México - Tijuana (UTC-8/-7)",            "America/Tijuana"},
    {"América/Colombia - Bogotá (UTC-5)",              "America/Bogota"},
    {"América/Argentina - Buenos Aires (UTC-3)",       "America/Argentina/Buenos_Aires"},
    {"América/Chile - Santiago (UTC-4/-3)",            "America/Santiago"},
    {"América/USA - Nueva York (UTC-5/-4)",            "America/New_York"},
    {"América/USA - Chicago (UTC-6/-5)",               "America/Chicago"},
    {"América/USA - Los Ángeles (UTC-8/-7)",           "America/Los_Angeles"},
    {"Europa/España - Madrid (UTC+1/+2)",              "Europe/Madrid"},
    {"UTC (Coordinated Universal Time)",               "Etc/UTC"},
  ]

  @impl true
  def mount(_params, _session, socket) do
    cfg = SysAdmin.get_config()
    {:ok,
     socket
     |> assign(:current_page, "configuracion")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:sidebar_open, true)
     |> assign(:current_path, "/admin/configuracion")
     |> assign(:timezone, cfg.timezone || "America/Mexico_City")
     |> assign(:flash_ok, false)
     |> assign(:timezones, @timezones)}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    AdminNav.handle_nav(id, socket, "configuracion")
  end

  @impl true
  def handle_event("guardar_timezone", %{"timezone" => tz}, socket) do
    case SysAdmin.save_config(%{timezone: tz}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:timezone, tz)
         |> assign(:flash_ok, true)
         |> put_flash(:info, "Zona horaria actualizada")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo guardar")}
    end
  end

  defp tz_label(timezones, tz) do
    case Enum.find(timezones, fn {_, v} -> v == tz end) do
      {label, _} -> label
      nil        -> tz
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-6 min-w-0">
    <div class="w-full px-4 py-8">

      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Configuración</h1>
        <p class="text-sm text-gray-500 mt-1">Ajustes generales del sistema</p>
      </div>

      <!-- ── Zona horaria ─────────────────────────────────── -->
      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
        <div class="px-6 py-5 border-b border-gray-100">
          <div class="flex items-center gap-3">
            <div class="flex items-center justify-center w-9 h-9 rounded-xl bg-violet-50">
              <svg class="w-5 h-5 text-violet-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h2 class="text-sm font-semibold text-gray-900">Zona horaria</h2>
              <p class="text-xs text-gray-500 mt-0.5">Las fechas de los pedidos se mostrarán en esta zona</p>
            </div>
          </div>
        </div>

        <form phx-submit="guardar_timezone" class="px-6 py-5">
          <div class="mb-5">
            <label class="block text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">
              Zona horaria actual
            </label>

            <!-- Vista actual -->
            <div class="mb-3 flex items-center gap-2 text-sm text-gray-700">
              <svg class="w-4 h-4 text-violet-500 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <span class="font-medium text-violet-700"><%= tz_label(@timezones, @timezone) %></span>
            </div>

            <select
              name="timezone"
              class="w-full px-3 py-2.5 rounded-xl border border-gray-200 bg-white text-sm text-gray-800 focus:outline-none focus:ring-2 focus:ring-violet-400 focus:border-transparent transition-all">
              <%= for {label, value} <- @timezones do %>
                <option value={value} selected={value == @timezone}><%= label %></option>
              <% end %>
            </select>

            <!-- Hora actual en la zona elegida -->
            <p class="mt-2 text-xs text-gray-400">
              Hora local ahora:
              <span class="font-medium text-gray-600">
                <%= format_now(@timezone) %>
              </span>
            </p>
          </div>

          <button
            type="submit"
            class="px-5 py-2.5 rounded-xl bg-gradient-to-br from-violet-600 to-indigo-600 text-white text-sm font-semibold hover:opacity-90 transition-opacity shadow-sm">
            Guardar zona horaria
          </button>
        </form>
      </div>

    </div>
      </div>
    </div>
    """
  end

  defp format_now(tz) do
    try do
      DateTime.utc_now()
      |> DateTime.shift_zone!(tz)
      |> Calendar.strftime("%d/%m/%Y %H:%M")
    rescue
      _ -> "—"
    end
  end
end
