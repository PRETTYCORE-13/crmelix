defmodule PrettycoreWeb.SeccionesLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Secciones
  alias Prettycore.Secciones.Seccion

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "secciones")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
      |> assign(:secciones, [])
      |> assign(:editando_id, nil)
      |> assign(:edit_nombre, "")

    if connected?(socket), do: send(self(), :load_secciones)
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_secciones, socket) do
    {:noreply, assign(socket, secciones: Secciones.list_secciones())}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"  -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"          -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"        -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "tienda"          -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "categorias"      -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"-> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"        -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"         -> {:noreply, socket}
      "usuarios"          -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "seccion_top10"     -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos" -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"-> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"-> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"    -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                   -> {:noreply, socket}
    end
  end

  def handle_event("toggle_activo", %{"id" => id}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == id))
    if sec do
      secs = Secciones.toggle_activo(sec)
      {:noreply, assign(socket, secciones: secs)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("reorder", %{"ids" => ids}, socket) do
    secs = Secciones.reorder(ids)
    {:noreply, assign(socket, secciones: secs)}
  end

  def handle_event("editar_nombre", %{"id" => id}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == id))
    {:noreply, assign(socket, editando_id: id, edit_nombre: sec && sec.nombre || "")}
  end

  def handle_event("guardar_nombre", %{"nombre" => nombre}, socket) do
    sec = Enum.find(socket.assigns.secciones, &(&1.id == socket.assigns.editando_id))
    if sec && String.trim(nombre) != "" do
      secs = Secciones.update_nombre(sec, String.trim(nombre))
      {:noreply, assign(socket, secciones: secs, editando_id: nil, edit_nombre: "")}
    else
      {:noreply, assign(socket, editando_id: nil)}
    end
  end

  def handle_event("cancelar_edicion", _, socket) do
    {:noreply, assign(socket, editando_id: nil, edit_nombre: "")}
  end


  # ── Render ────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-6 min-h-screen bg-gray-50">
      <header class="mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Secciones de la Tienda</h1>
          <p class="text-sm text-gray-500 mt-0.5">Define qué bloques aparecen en la tienda y en qué orden</p>
        </div>
      </header>

      <!-- Info -->
      <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-xl flex items-start gap-2.5">
        <svg class="w-4 h-4 text-blue-500 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <p class="text-xs text-blue-700">Activa las secciones que quieras mostrar y ordénalas arrastrando con el mouse desde el ícono ⠿. Solo las secciones activas aparecen en la tienda.</p>
      </div>

      <!-- Lista de secciones (drag-and-drop) -->
      <div id="secciones-list" phx-hook="DragSort" class="space-y-2">
        <%= for {sec, i} <- Enum.with_index(@secciones) do %>
          <div
            data-drag-id={sec.id}
            draggable="true"
            class={"flex items-center gap-3 p-4 rounded-2xl border transition-all select-none #{if sec.activo, do: "bg-white border-gray-200 shadow-sm", else: "bg-gray-50 border-gray-100"}"}
          >
            <!-- Drag handle -->
            <div class="flex-shrink-0 cursor-grab active:cursor-grabbing text-gray-300 hover:text-gray-500 transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <circle cx="9" cy="6" r="1.5"/><circle cx="15" cy="6" r="1.5"/>
                <circle cx="9" cy="12" r="1.5"/><circle cx="15" cy="12" r="1.5"/>
                <circle cx="9" cy="18" r="1.5"/><circle cx="15" cy="18" r="1.5"/>
              </svg>
            </div>

            <!-- Orden -->
            <div class="flex-shrink-0 w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center text-xs font-bold text-gray-500">
              <%= i + 1 %>
            </div>

            <!-- Type badge -->
            <div class={"flex-shrink-0 px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wide #{tipo_color(sec.tipo)}"}>
              <%= Seccion.tipo_label(sec.tipo) %>
            </div>

            <!-- Name (editable) -->
            <div class="flex-1 min-w-0">
              <%= if @editando_id == sec.id do %>
                <form phx-submit="guardar_nombre" class="flex items-center gap-2">
                  <input type="text" name="nombre" value={@edit_nombre} autofocus
                    class="flex-1 px-2 py-1 border border-purple-400 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                  <button type="submit" class="px-2 py-1 bg-purple-600 text-white rounded-lg text-xs font-medium hover:bg-purple-500">OK</button>
                  <button type="button" phx-click="cancelar_edicion" class="px-2 py-1 text-gray-500 hover:text-gray-700 text-xs">✕</button>
                </form>
              <% else %>
                <div class="flex items-center gap-2">
                  <span class={"text-sm font-semibold #{if sec.activo, do: "text-gray-900", else: "text-gray-400"}"}><%= sec.nombre %></span>
                  <button phx-click="editar_nombre" phx-value-id={sec.id}
                    class="p-0.5 text-gray-300 hover:text-purple-600 transition-colors">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                    </svg>
                  </button>
                </div>
                <%= if sec.activo do %>
                  <p class="text-xs text-green-600 font-medium mt-0.5">Visible en tienda</p>
                <% else %>
                  <p class="text-xs text-gray-400 mt-0.5">Oculta</p>
                <% end %>
              <% end %>
            </div>

            <!-- Controls -->
            <div class="flex items-center gap-2 flex-shrink-0">
              <!-- Toggle activo -->
              <button phx-click="toggle_activo" phx-value-id={sec.id}
                class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none #{if sec.activo, do: "bg-purple-600", else: "bg-gray-200"}"}>
                <span class={"inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform #{if sec.activo, do: "translate-x-6", else: "translate-x-1"}"}></span>
              </button>

            </div>
          </div>
        <% end %>
      </div>

    </section>
    """
  end

  defp tipo_color("carrusel"),   do: "bg-indigo-100 text-indigo-700"
  defp tipo_color("productos"),  do: "bg-blue-100 text-blue-700"
  defp tipo_color("top10"),      do: "bg-yellow-100 text-yellow-700"
  defp tipo_color("favoritos"),  do: "bg-red-100 text-red-700"
  defp tipo_color("destacados"), do: "bg-orange-100 text-orange-700"
  defp tipo_color("publicidad"), do: "bg-purple-100 text-purple-700"
  defp tipo_color("envios"),     do: "bg-green-100 text-green-700"
  defp tipo_color(_),            do: "bg-gray-100 text-gray-700"
end
