defmodule PrettycoreWeb.Inicio do
  use PrettycoreWeb, :live_view_admin

  import PrettycoreWeb.MenuLayout

  # Recibimos el :email desde la ruta /admin/platform/:email
  def mount(_params, _session, socket) do
    current_path = "/admin/platform"

    {:ok,
     socket
     |> assign(:current_page, "inicio")
     |> assign(:sidebar_open, true)
     |> assign(:show_programacion_children, false)
     |> assign(:current_path, current_path)}
  end

  ## Navegación centralizada con CASE (modelo recomendado)
  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    email = socket.assigns.current_user_email

    case id do
      "toggle_sidebar" ->
        {:noreply, update(socket, :sidebar_open, &(not &1))}

      "inicio" ->
        {:noreply,
         socket
         |> assign(:current_page, "inicio")
         |> assign(:show_programacion_children, false)
         |> push_navigate(to: ~p"/admin/platform")}

      "programacion" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/programacion")}

      "programacion_sql" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/programacion/sql")}

      "workorder" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/workorder")}

      "clientes" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}

      "tienda" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}

      "categorias" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}

      "usuarios" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}

      "analisis" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/analisis")}

  #    "config" ->
  #      {:noreply, push_navigate(socket, to: ~p"/admin/configuracion")}

      _ ->
        {:noreply, socket}
    end
  end

  ## Render
  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-3 sm:p-6 max-w-7xl mx-auto min-h-screen bg-gray-50">
      <header class="mb-4 sm:mb-6">
        <h1 class="text-lg sm:text-2xl font-bold text-gray-900">Inicio</h1>
        <p class="text-xs sm:text-sm text-gray-500 mt-0.5">zzzzz</p>
      </header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <!-- Iframe de prettycore.xyz -->
        <div class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="bg-gradient-to-r from-gray-800 to-black px-4 py-2.5 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-red-400"></div>
              <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
              <div class="w-3 h-3 rounded-full bg-green-400"></div>
              <span class="ml-2 text-white/70 text-xs font-mono">prettycore.xyz</span>
            </div>
            <a href="https://prettycore.xyz/" target="_blank" class="text-white/50 hover:text-white transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" /><polyline points="15 3 21 3 21 9" /><line x1="10" y1="14" x2="21" y2="3" />
              </svg>
            </a>
          </div>
          <iframe
            src="https://prettycore.xyz/"
            class="w-full border-0"
            style="height: 70vh;"
            title="PrettyCore Website"
          ></iframe>
        </div>

        <!-- Iframe de ventaenruta.com.mx -->
        <div class="bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="bg-gradient-to-r from-gray-800 to-black px-4 py-2.5 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <div class="w-3 h-3 rounded-full bg-red-400"></div>
              <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
              <div class="w-3 h-3 rounded-full bg-green-400"></div>
              <span class="ml-2 text-white/70 text-xs font-mono">ventaenruta.com.mx</span>
            </div>
            <a href="https://ventaenruta.com.mx/" target="_blank" class="text-white/50 hover:text-white transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" /><polyline points="15 3 21 3 21 9" /><line x1="10" y1="14" x2="21" y2="3" />
              </svg>
            </a>
          </div>
          <iframe
            src="https://ventaenruta.com.mx/"
            class="w-full border-0"
            style="height: 70vh;"
            title="Venta en Ruta Website"
          ></iframe>
        </div>
      </div>
    </section>
    """
  end
end
