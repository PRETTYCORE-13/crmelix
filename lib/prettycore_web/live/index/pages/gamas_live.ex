defmodule PrettycoreWeb.GamasLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Gamas
  alias Prettycore.ProductosNativos

  @impl true
  def mount(_params, _session, socket) do
    productos     = ProductosNativos.list_para_gamas()
    gamas         = Gamas.list_gamas()
    numeros       = Enum.map(gamas, & &1.numero)
    numero_activo = (List.first(gamas) || %{numero: 1}).numero
    siguiente     = (List.last(numeros) || 0) + 1

    {:ok,
     socket
     |> assign(:current_page, "gamas")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:productos, productos)
     |> assign(:gamas, gamas)
     |> assign(:numero_activo, numero_activo)
     |> assign(:codigos_en_gama, MapSet.new(Gamas.codigos_en_gama(numero_activo)))
     |> assign(:search, "")
     |> assign(:siguiente_numero, siguiente)
     # modo :editar | :nueva
     |> assign(:modo, :editar)
     |> assign(:nuevo_nombre, "")
     |> assign(:codigos_nuevos, MapSet.new())
    }
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "gamas")
  end

  # ── Modo: iniciar creación ────────────────────────────────────────────────────

  @impl true
  def handle_event("iniciar_nueva", _params, socket) do
    {:noreply, assign(socket, modo: :nueva, nuevo_nombre: "", codigos_nuevos: MapSet.new(), search: "")}
  end

  @impl true
  def handle_event("cancelar_nueva", _params, socket) do
    {:noreply, assign(socket, modo: :editar, nuevo_nombre: "", codigos_nuevos: MapSet.new(), search: "")}
  end

  # ── Seleccionar gama activa ────────────────────────────────────────────────

  @impl true
  def handle_event("seleccionar_gama", %{"numero" => n_str}, socket) do
    numero = String.to_integer(n_str)
    codigos = MapSet.new(Gamas.codigos_en_gama(numero))
    {:noreply, assign(socket, numero_activo: numero, codigos_en_gama: codigos, search: "", modo: :editar)}
  end

  # ── Toggle producto en gama nueva (solo en memoria) ─────────────────────────

  @impl true
  def handle_event("toggle_nuevo", %{"codigo" => codigo}, socket) do
    codigos =
      if MapSet.member?(socket.assigns.codigos_nuevos, codigo),
        do: MapSet.delete(socket.assigns.codigos_nuevos, codigo),
        else: MapSet.put(socket.assigns.codigos_nuevos, codigo)
    {:noreply, assign(socket, codigos_nuevos: codigos)}
  end

  # ── Confirmar creación (requiere nombre + al menos 1 producto) ───────────────

  @impl true
  def handle_event("crear_gama", %{"nombre" => nombre}, socket) do
    nombre_trim = String.trim(nombre)
    codigos     = socket.assigns.codigos_nuevos

    cond do
      nombre_trim == "" ->
        {:noreply, put_flash(socket, :error, "El nombre es obligatorio")}
      MapSet.size(codigos) == 0 ->
        {:noreply, put_flash(socket, :error, "Selecciona al menos un producto")}
      true ->
        n = socket.assigns.siguiente_numero
        Gamas.crear_gama(n, nombre_trim)
        Enum.each(codigos, fn cod -> Gamas.agregar(n, cod) end)
        gamas     = Gamas.list_gamas()
        numeros   = Enum.map(gamas, & &1.numero)
        siguiente = (List.last(numeros) || 0) + 1
        {:noreply,
         socket
         |> assign(gamas: gamas, numero_activo: n, siguiente_numero: siguiente,
                   codigos_en_gama: MapSet.new(Gamas.codigos_en_gama(n)),
                   modo: :editar, nuevo_nombre: "", codigos_nuevos: MapSet.new(), search: "")
         |> put_flash(:info, "Gama #{n} — #{nombre_trim} creada con #{MapSet.size(codigos)} productos.")}
    end
  end

  # ── Toggle producto en gama existente (auto-save) ───────────────────────────

  @impl true
  def handle_event("toggle_producto", %{"codigo" => codigo}, socket) do
    numero  = socket.assigns.numero_activo
    codigos = socket.assigns.codigos_en_gama

    codigos =
      if MapSet.member?(codigos, codigo) do
        Gamas.quitar(numero, codigo)
        MapSet.delete(codigos, codigo)
      else
        Gamas.agregar(numero, codigo)
        MapSet.put(codigos, codigo)
      end

    {:noreply, assign(socket, codigos_en_gama: codigos)}
  end

  # ── Eliminar gama ───────────────────────────────────────────────────────────

  @impl true
  def handle_event("eliminar_gama", %{"numero" => n_str}, socket) do
    numero = String.to_integer(n_str)
    Gamas.eliminar_gama(numero)
    gamas        = Gamas.list_gamas()
    nuevo_activo = (List.first(gamas) || %{numero: 1}).numero
    siguiente    = (List.last(Enum.map(gamas, & &1.numero)) || 0) + 1
    {:noreply,
     socket
     |> assign(gamas: gamas, numero_activo: nuevo_activo, siguiente_numero: siguiente,
               codigos_en_gama: MapSet.new(Gamas.codigos_en_gama(nuevo_activo)),
               modo: :editar)
     |> put_flash(:info, "Gama #{numero} eliminada")}
  end

  # ── Actualizar nombre de nueva gama ─────────────────────────────────────────

  @impl true
  def handle_event("update_nombre", %{"value" => v}, socket) do
    {:noreply, assign(socket, nuevo_nombre: v)}
  end

  # ── Búsqueda ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"value" => q}, socket) do
    {:noreply, assign(socket, search: q)}
  end

  # ── Render ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 sm:p-6 space-y-5">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Gamas de Productos</h1>
        <p class="text-sm text-gray-500 mt-0.5">Define qué productos puede ver cada grupo de clientes</p>
      </div>

      <div class="flex flex-col lg:flex-row gap-6">

        <!-- Panel izquierdo: lista de gamas -->
        <div class="w-full lg:w-64 flex-shrink-0 space-y-3">

          <!-- Botón nueva gama -->
          <%= if @modo == :editar do %>
            <button type="button" phx-click="iniciar_nueva"
              class="w-full flex items-center justify-center gap-2 py-2.5 bg-purple-600 hover:bg-purple-500 text-white text-sm font-semibold rounded-xl transition-colors">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4"/>
              </svg>
              Nueva Gama
            </button>
          <% else %>
            <div class="bg-purple-50 border border-purple-200 rounded-xl p-3 space-y-2">
              <p class="text-xs font-bold text-purple-700 uppercase tracking-wide">Nueva gama · # <%= @siguiente_numero %></p>
              <input type="text" id="input-nuevo-nombre" value={@nuevo_nombre}
                phx-keyup="update_nombre" placeholder="Nombre (obligatorio)"
                maxlength="60"
                class="w-full px-3 py-2 text-sm border border-purple-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-purple-500 bg-white" />
              <p class="text-[11px] text-purple-500">
                <%= if MapSet.size(@codigos_nuevos) == 0 do %>
                  Selecciona al menos un producto →
                <% else %>
                  <%= MapSet.size(@codigos_nuevos) %> producto(s) seleccionado(s)
                <% end %>
              </p>
            </div>
          <% end %>

          <!-- Lista de gamas existentes -->
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <p class="text-xs font-bold text-gray-500 uppercase tracking-wide px-4 pt-3 pb-1">Gamas existentes</p>
            <%= if @gamas == [] do %>
              <p class="text-xs text-gray-400 px-4 pb-4">Sin gamas aún</p>
            <% else %>
              <div class="divide-y divide-gray-100">
                <%= for g <- @gamas do %>
                  <% activa = @modo == :editar and g.numero == @numero_activo %>
                  <div class={"flex items-center justify-between px-4 py-2.5 transition-colors #{if activa, do: "bg-purple-50", else: "hover:bg-gray-50 cursor-pointer"}"}
                    phx-click="seleccionar_gama" phx-value-numero={g.numero}>
                    <div class="min-w-0">
                      <p class={"text-sm font-semibold truncate #{if activa, do: "text-purple-700", else: "text-gray-700"}"}>
                        <%= g.nombre || "Gama #{g.numero}" %>
                      </p>
                      <p class="text-[10px] text-gray-400"># <%= g.numero %></p>
                    </div>
                    <button type="button" phx-click="eliminar_gama" phx-value-numero={g.numero}
                      data-confirm={"¿Eliminar la Gama #{g.numero}? Se borrará el catálogo completo."}
                      class="p-1 ml-2 flex-shrink-0 text-gray-300 hover:text-red-500 transition-colors">
                      <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

        </div>

        <!-- Panel derecho: catálogo de productos -->
        <div class="flex-1 min-w-0">

          <!-- Cabecera del panel derecho -->
          <div class="flex items-center justify-between mb-3">
            <div>
              <%= if @modo == :nueva do %>
                <h2 class="text-base font-bold text-gray-900">Selecciona los productos</h2>
                <p class="text-xs text-gray-400">Elige los productos que tendrá esta gama</p>
              <% else %>
                <% gama_activa = Enum.find(@gamas, &(&1.numero == @numero_activo)) %>
                <h2 class="text-base font-bold text-gray-900">
                  <%= (gama_activa && gama_activa.nombre) || "Gama #{@numero_activo}" %>
                </h2>
                <p class="text-xs text-gray-400"># <%= @numero_activo %> · <%= MapSet.size(@codigos_en_gama) %> productos</p>
              <% end %>
            </div>
            <!-- Buscador + botones de acción -->
            <div class="flex items-center gap-2">
              <%= if @modo == :nueva do %>
                <button type="button" phx-click="cancelar_nueva"
                  class="px-3 py-2 text-sm text-gray-500 hover:text-gray-700 border border-gray-200 rounded-xl transition-colors">
                  Cancelar
                </button>
                <form phx-submit="crear_gama">
                  <input type="hidden" name="nombre" value={@nuevo_nombre} />
                  <button type="submit"
                    class={"px-4 py-2 text-sm font-semibold rounded-xl transition-colors #{if MapSet.size(@codigos_nuevos) > 0, do: "bg-purple-600 hover:bg-purple-500 text-white", else: "bg-gray-100 text-gray-400 cursor-not-allowed"}"}>
                    Crear Gama
                  </button>
                </form>
              <% end %>
              <div class="relative w-52">
                <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <svg class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                  </svg>
                </div>
                <input type="text" phx-keyup="search" value={@search}
                  placeholder="Buscar producto..."
                  class="block w-full pl-9 pr-4 py-2 bg-white border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none shadow-sm" />
              </div>
            </div>
          </div>

          <!-- Aviso si modo nueva y sin nombre -->
          <%= if @modo == :nueva and String.trim(@nuevo_nombre) == "" do %>
            <div class="mb-3 px-4 py-2.5 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-700 font-medium">
              Escribe el nombre de la gama en el panel izquierdo antes de confirmar.
            </div>
          <% end %>

          <%
            words = @search |> String.downcase() |> String.split(" ", trim: true)
            filtered =
              if words == [],
                do: @productos,
                else: Enum.filter(@productos, fn p ->
                  desc = String.downcase(p.descripcion || "")
                  cod  = String.downcase(p.codigo || "")
                  Enum.all?(words, fn w -> String.contains?(desc, w) or String.contains?(cod, w) end)
                end)
          %>

          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-4 xl:grid-cols-5 gap-3 max-h-[72vh] overflow-y-auto pr-1">
            <%= for prod <- filtered do %>
              <% {evento, seleccionado} =
                   if @modo == :nueva,
                     do: {"toggle_nuevo", MapSet.member?(@codigos_nuevos, prod.codigo)},
                     else: {"toggle_producto", MapSet.member?(@codigos_en_gama, prod.codigo)} %>
              <button type="button" phx-click={evento} phx-value-codigo={prod.codigo}
                class={"relative bg-white rounded-xl overflow-hidden border-2 transition-all #{if seleccionado, do: "border-purple-500 shadow-md", else: "border-gray-100 hover:border-gray-300"}"}>
                <div class="aspect-square bg-gray-50 overflow-hidden">
                  <%= if prod.imagen_url && prod.imagen_url != "" do %>
                    <img src={prod.imagen_url} alt={prod.descripcion} class="w-full h-full object-cover" />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center">
                      <svg class="w-8 h-8 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                    </div>
                  <% end %>
                </div>
                <div class="p-2 text-left">
                  <p class="text-[10px] font-semibold text-gray-800 line-clamp-2 leading-tight"><%= prod.descripcion %></p>
                  <p class="text-[9px] text-gray-400 font-mono mt-0.5"><%= prod.codigo %></p>
                </div>
                <%= if seleccionado do %>
                  <div class="absolute top-1.5 right-1.5 w-5 h-5 bg-purple-600 rounded-full flex items-center justify-center">
                    <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>

      </div>
    </div>
    """
  end
end
