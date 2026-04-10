defmodule PrettycoreWeb.SucursalesLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Sucursales
  alias Prettycore.Sucursales.Sucursal

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "sucursales")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:sidebar_open, true)
     |> assign(:sucursales, Sucursales.list_todas())
     |> assign(:modal, nil)
     |> assign(:selected, nil)
     |> assign(:form_numero, "")
     |> assign(:form_nombre, "")
     |> assign(:form_direccion, "")
     |> assign(:form_activo, true)
     |> assign(:form_error, nil)}
  end

  # ── Navegación ───────────────────────────────────────────────────────────────

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"             -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}
      "categorias"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"           -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"                  -> {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}
      "usuarios"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, socket}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Modales ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("nueva", _, socket) do
    {:noreply, socket
     |> assign(:modal, :nueva)
     |> assign(:selected, nil)
     |> assign(:form_numero, Sucursales.next_numero())
     |> assign(:form_nombre, "")
     |> assign(:form_direccion, "")
     |> assign(:form_activo, true)
     |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("editar", %{"id" => id}, socket) do
    case Sucursales.get(id) do
      nil -> {:noreply, socket}
      s ->
        {:noreply, socket
         |> assign(:modal, :editar)
         |> assign(:selected, s)
         |> assign(:form_numero, s.numero)
         |> assign(:form_nombre, s.nombre)
         |> assign(:form_direccion, s.direccion || "")
         |> assign(:form_activo, s.activo)
         |> assign(:form_error, nil)}
    end
  end

  @impl true
  def handle_event("cerrar_modal", _, socket) do
    {:noreply, assign(socket, modal: nil, selected: nil, form_error: nil)}
  end

  @impl true
  def handle_event("toggle_activo_form", _, socket) do
    {:noreply, update(socket, :form_activo, &(not &1))}
  end

  @impl true
  def handle_event("guardar", params, socket) do
    attrs = %{
      "numero"    => socket.assigns.form_numero,
      "nombre"    => String.trim(params["nombre"] || ""),
      "direccion" => String.trim(params["direccion"] || ""),
      "activo"    => socket.assigns.form_activo
    }

    result =
      case socket.assigns.modal do
        :nueva  -> Sucursales.crear(attrs)
        :editar -> Sucursales.actualizar(socket.assigns.selected, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply, socket
         |> assign(:modal, nil)
         |> assign(:sucursales, Sucursales.list_todas())}

      {:error, changeset} ->
        msg = changeset.errors |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end) |> Enum.join(", ")
        {:noreply, assign(socket, :form_error, msg)}
    end
  end

  @impl true
  def handle_event("eliminar", %{"id" => id}, socket) do
    case Sucursales.get(id) do
      nil -> {:noreply, socket}
      s ->
        Sucursales.eliminar(s)
        {:noreply, assign(socket, :sucursales, Sucursales.list_todas())}
    end
  end

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-6 min-w-0">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-gray-900">Sucursales</h1>
        <button
          phx-click="nueva"
          class="flex items-center gap-2 px-4 py-2 bg-gray-900 text-white text-sm font-medium rounded-xl hover:bg-gray-700 transition"
        >
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/>
          </svg>
          Nueva Sucursal
        </button>
      </div>

      <!-- Tabla -->
      <div class="bg-white rounded-2xl border border-gray-200 overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 border-b border-gray-200">
            <tr>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">#</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nombre</th>
              <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Dirección</th>
              <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Activa</th>
              <th class="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase">Acciones</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for s <- @sucursales do %>
              <tr class="hover:bg-gray-50 transition">
                <td class="px-4 py-3 font-mono font-semibold text-gray-700"><%= s.numero %></td>
                <td class="px-4 py-3 font-medium text-gray-900"><%= s.nombre %></td>
                <td class="px-4 py-3 text-gray-500"><%= s.direccion || "—" %></td>
                <td class="px-4 py-3 text-center">
                  <span class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium #{if s.activo, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500"}"}>
                    <%= if s.activo, do: "Sí", else: "No" %>
                  </span>
                </td>
                <td class="px-4 py-3 text-right">
                  <div class="flex justify-end gap-2">
                    <button
                      phx-click="editar"
                      phx-value-id={s.id}
                      class="px-3 py-1.5 text-xs font-medium rounded-lg border border-gray-200 hover:bg-gray-100 transition"
                    >Editar</button>
                    <button
                      phx-click="eliminar"
                      phx-value-id={s.id}
                      data-confirm="¿Eliminar esta sucursal?"
                      class="px-3 py-1.5 text-xs font-medium rounded-lg border border-red-200 text-red-600 hover:bg-red-50 transition"
                    >Eliminar</button>
                  </div>
                </td>
              </tr>
            <% end %>
            <%= if @sucursales == [] do %>
              <tr>
                <td colspan="5" class="px-4 py-8 text-center text-sm text-gray-400">
                  No hay sucursales registradas.
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <!-- Modal -->
      <%= if @modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
          <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4">
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h2 class="text-base font-bold text-gray-900">
                <%= if @modal == :nueva, do: "Nueva Sucursal", else: "Editar Sucursal" %>
              </h2>
              <button phx-click="cerrar_modal" class="text-gray-400 hover:text-gray-600">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <%= if @form_error do %>
              <div class="mx-6 mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl">
                <%= @form_error %>
              </div>
            <% end %>

            <form phx-submit="guardar" class="px-6 py-5 space-y-4">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                    Número
                  </label>
                  <input
                    type="number"
                    name="numero_display"
                    value={@form_numero}
                    readonly
                    class="w-full text-sm rounded-lg border px-3 py-2 bg-gray-50 border-gray-200 text-gray-500 focus:outline-none"
                  />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                    Nombre *
                  </label>
                  <input
                    type="text"
                    name="nombre"
                    value={@form_nombre}
                    placeholder="Ej: Sucursal Centro"
                    required
                    class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                  />
                </div>
              </div>

              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Dirección
                </label>
                <input
                  type="text"
                  name="direccion"
                  value={@form_direccion}
                  placeholder="Opcional"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>

              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm font-medium text-gray-700">Activa</p>
                  <p class="text-xs text-gray-400">La sucursal aparece en el sistema.</p>
                </div>
                <button
                  type="button"
                  phx-click="toggle_activo_form"
                  class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors #{if @form_activo, do: "bg-gray-900", else: "bg-gray-300"}"}
                >
                  <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform #{if @form_activo, do: "translate-x-6", else: "translate-x-1"}"} />
                </button>
              </div>

              <div class="flex gap-3 pt-2">
                <button type="button" phx-click="cerrar_modal"
                  class="flex-1 py-2 text-sm font-medium rounded-xl border border-gray-200 hover:bg-gray-50 transition">
                  Cancelar
                </button>
                <button type="submit"
                  class="flex-1 py-2 text-sm font-medium rounded-xl bg-gray-900 text-white hover:bg-gray-700 transition">
                  <%= if @modal == :nueva, do: "Crear Sucursal", else: "Guardar Cambios" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    </div>
    """
  end
end
