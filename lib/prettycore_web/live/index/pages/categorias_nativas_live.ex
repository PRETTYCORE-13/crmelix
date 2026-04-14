defmodule PrettycoreWeb.CategoriasNativasLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.CategoriasNativas
  alias Prettycore.CategoriasNativas.CategoriaNativa
  alias Prettycore.SuperCategoriasNativas
  alias Prettycore.SuperCategoriasNativas.SuperCategoriaNativa

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "categorias_nativas")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:tab, :categorias)
     |> assign(:categorias, CategoriasNativas.list_todas())
     |> assign(:super_categorias, SuperCategoriasNativas.list_todas())
     |> assign(:modal, nil)
     |> assign(:modal_tipo, nil)
     |> assign(:selected, nil)
     |> assign(:form_nombre, "")
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
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, socket}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Tabs ─────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  # ── Modal ────────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("nueva_categoria", _, socket) do
    {:noreply, socket |> assign(:modal, :nueva) |> assign(:modal_tipo, :categoria)
     |> assign(:selected, nil) |> assign(:form_nombre, "") |> assign(:form_activo, true) |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("nueva_super_categoria", _, socket) do
    {:noreply, socket |> assign(:modal, :nueva) |> assign(:modal_tipo, :super_categoria)
     |> assign(:selected, nil) |> assign(:form_nombre, "") |> assign(:form_activo, true) |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("editar", %{"id" => id, "tipo" => tipo}, socket) do
    tipo_atom = String.to_existing_atom(tipo)
    item = case tipo_atom do
      :categoria       -> CategoriasNativas.get(id)
      :super_categoria -> SuperCategoriasNativas.get(id)
    end
    case item do
      nil -> {:noreply, socket}
      it ->
        {:noreply, socket
         |> assign(:modal, :editar)
         |> assign(:modal_tipo, tipo_atom)
         |> assign(:selected, it)
         |> assign(:form_nombre, it.nombre)
         |> assign(:form_activo, it.activo)
         |> assign(:form_error, nil)}
    end
  end

  @impl true
  def handle_event("cerrar_modal", _, socket) do
    {:noreply, assign(socket, modal: nil, modal_tipo: nil, selected: nil, form_error: nil)}
  end

  @impl true
  def handle_event("toggle_activo_form", _, socket) do
    {:noreply, update(socket, :form_activo, &(not &1))}
  end

  # ── Guardar ──────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", params, socket) do
    attrs = %{"nombre" => String.trim(params["nombre"] || ""), "activo" => socket.assigns.form_activo}

    result =
      case {socket.assigns.modal, socket.assigns.modal_tipo} do
        {:nueva, :categoria}            -> CategoriasNativas.crear(attrs)
        {:nueva, :super_categoria}      -> SuperCategoriasNativas.crear(attrs)
        {:editar, :categoria}           -> CategoriasNativas.actualizar(socket.assigns.selected, attrs)
        {:editar, :super_categoria}     -> SuperCategoriasNativas.actualizar(socket.assigns.selected, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply, socket
         |> assign(:modal, nil)
         |> assign(:categorias, CategoriasNativas.list_todas())
         |> assign(:super_categorias, SuperCategoriasNativas.list_todas())
         |> put_flash(:info, "Guardado correctamente")}

      {:error, cs} ->
        msg = cs.errors |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end) |> Enum.join(", ")
        {:noreply, assign(socket, :form_error, msg)}
    end
  end

  # ── Eliminar ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("eliminar", %{"id" => id, "tipo" => tipo}, socket) do
    case String.to_existing_atom(tipo) do
      :categoria ->
        case CategoriasNativas.get(id) do
          nil -> :ok
          c   -> CategoriasNativas.eliminar(c)
        end
      :super_categoria ->
        case SuperCategoriasNativas.get(id) do
          nil -> :ok
          sc  -> SuperCategoriasNativas.eliminar(sc)
        end
    end
    {:noreply, socket
     |> assign(:categorias, CategoriasNativas.list_todas())
     |> assign(:super_categorias, SuperCategoriasNativas.list_todas())}
  end

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-6 min-w-0">
      <h1 class="text-xl font-bold text-gray-900 mb-6">Categorías Nativas</h1>

      <!-- Tabs -->
      <div class="flex gap-2 mb-6 border-b border-gray-200">
        <button
          phx-click="switch_tab" phx-value-tab="categorias"
          class={"px-4 py-2 text-sm font-medium border-b-2 -mb-px transition " <>
            if @tab == :categorias, do: "border-gray-900 text-gray-900", else: "border-transparent text-gray-400 hover:text-gray-600"}
        >Categorías</button>
        <button
          phx-click="switch_tab" phx-value-tab="super_categorias"
          class={"px-4 py-2 text-sm font-medium border-b-2 -mb-px transition " <>
            if @tab == :super_categorias, do: "border-gray-900 text-gray-900", else: "border-transparent text-gray-400 hover:text-gray-600"}
        >Super Categorías</button>
      </div>

      <%= if @tab == :categorias do %>
        <div class="flex justify-between items-center mb-4">
          <p class="text-sm text-gray-500"><%= length(@categorias) %> categoría(s)</p>
          <button phx-click="nueva_categoria"
            class="flex items-center gap-2 px-4 py-2 bg-gray-900 text-white text-sm font-medium rounded-xl hover:bg-gray-700 transition">
            + Nueva Categoría
          </button>
        </div>
        <div class="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 border-b border-gray-200">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nombre</th>
                <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Activa</th>
                <th class="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for c <- @categorias do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-3 font-medium text-gray-900"><%= c.nombre %></td>
                  <td class="px-4 py-3 text-center">
                    <span class={"inline-flex px-2 py-0.5 rounded-full text-xs font-medium #{if c.activo, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500"}"}>
                      <%= if c.activo, do: "Sí", else: "No" %>
                    </span>
                  </td>
                  <td class="px-4 py-3 text-right">
                    <div class="flex justify-end gap-2">
                      <button phx-click="editar" phx-value-id={c.id} phx-value-tipo="categoria"
                        class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-100 transition">Editar</button>
                      <button phx-click="eliminar" phx-value-id={c.id} phx-value-tipo="categoria"
                        data-confirm="¿Eliminar esta categoría?"
                        class="px-3 py-1.5 text-xs rounded-lg border border-red-200 text-red-600 hover:bg-red-50 transition">Eliminar</button>
                    </div>
                  </td>
                </tr>
              <% end %>
              <%= if @categorias == [] do %>
                <tr><td colspan="3" class="px-4 py-8 text-center text-sm text-gray-400">Sin categorías aún.</td></tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% else %>
        <div class="flex justify-between items-center mb-4">
          <p class="text-sm text-gray-500"><%= length(@super_categorias) %> super categoría(s)</p>
          <button phx-click="nueva_super_categoria"
            class="flex items-center gap-2 px-4 py-2 bg-gray-900 text-white text-sm font-medium rounded-xl hover:bg-gray-700 transition">
            + Nueva Super Categoría
          </button>
        </div>
        <div class="bg-white rounded-2xl border border-gray-200 overflow-hidden">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 border-b border-gray-200">
              <tr>
                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Nombre</th>
                <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase">Activa</th>
                <th class="px-4 py-3 text-right text-xs font-semibold text-gray-500 uppercase">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for sc <- @super_categorias do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-3 font-medium text-gray-900"><%= sc.nombre %></td>
                  <td class="px-4 py-3 text-center">
                    <span class={"inline-flex px-2 py-0.5 rounded-full text-xs font-medium #{if sc.activo, do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500"}"}>
                      <%= if sc.activo, do: "Sí", else: "No" %>
                    </span>
                  </td>
                  <td class="px-4 py-3 text-right">
                    <div class="flex justify-end gap-2">
                      <button phx-click="editar" phx-value-id={sc.id} phx-value-tipo="super_categoria"
                        class="px-3 py-1.5 text-xs rounded-lg border border-gray-200 hover:bg-gray-100 transition">Editar</button>
                      <button phx-click="eliminar" phx-value-id={sc.id} phx-value-tipo="super_categoria"
                        data-confirm="¿Eliminar esta super categoría?"
                        class="px-3 py-1.5 text-xs rounded-lg border border-red-200 text-red-600 hover:bg-red-50 transition">Eliminar</button>
                    </div>
                  </td>
                </tr>
              <% end %>
              <%= if @super_categorias == [] do %>
                <tr><td colspan="3" class="px-4 py-8 text-center text-sm text-gray-400">Sin super categorías aún.</td></tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>

    <!-- Modal -->
    <%= if @modal do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm mx-4">
          <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <h2 class="text-base font-bold text-gray-900">
              <%= cond do
                @modal == :nueva && @modal_tipo == :categoria       -> "Nueva Categoría"
                @modal == :nueva && @modal_tipo == :super_categoria -> "Nueva Super Categoría"
                @modal == :editar && @modal_tipo == :categoria      -> "Editar Categoría"
                true                                                -> "Editar Super Categoría"
              end %>
            </h2>
            <button phx-click="cerrar_modal" class="text-gray-400 hover:text-gray-600">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
          <%= if @form_error do %>
            <div class="mx-6 mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl"><%= @form_error %></div>
          <% end %>
          <form phx-submit="guardar" class="px-6 py-5 space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Nombre *</label>
              <input type="text" name="nombre" value={@form_nombre} required
                maxlength="150"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                placeholder="Ej: Lácteos" />
            </div>
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-gray-700">Activa</p>
              <button type="button" phx-click="toggle_activo_form"
                class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors #{if @form_activo, do: "bg-gray-900", else: "bg-gray-300"}"}>
                <span class={"inline-block h-4 w-4 transform rounded-full bg-white transition-transform #{if @form_activo, do: "translate-x-6", else: "translate-x-1"}"} />
              </button>
            </div>
            <div class="flex gap-3 pt-2">
              <button type="button" phx-click="cerrar_modal"
                class="flex-1 py-2 text-sm font-medium rounded-xl border border-gray-200 hover:bg-gray-50 transition">Cancelar</button>
              <button type="submit"
                class="flex-1 py-2 text-sm font-medium rounded-xl bg-gray-900 text-white hover:bg-gray-700 transition">Guardar</button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    </div>
    """
  end
end
