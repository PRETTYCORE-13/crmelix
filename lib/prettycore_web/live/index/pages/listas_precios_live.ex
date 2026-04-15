defmodule PrettycoreWeb.ListasPreciosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.ListasPrecios
  alias Prettycore.ProductosNativos

  @impl true
  def mount(_params, _session, socket) do
    productos = ProductosNativos.list_todos()
    numeros   = ListasPrecios.numeros_disponibles()
    # Número activo: el primero disponible o 1
    numero_activo = List.first(numeros) || 1

    {:ok,
     socket
     |> assign(:current_page, "listas_precios")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:productos, productos)
     |> assign(:numeros, numeros)
     |> assign(:numero_activo, numero_activo)
     |> assign(:precios_map, ListasPrecios.get_precios_map(numero_activo))
     |> assign(:search, "")
     |> assign(:nuevo_numero, "")
     |> assign(:guardando, false)
     |> assign(:saved, false)
     |> assign(:edits, %{})        # %{producto_codigo => precio_string} pendientes de guardar
    }
  end

  # ── Navegación ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"    -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "inicio"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, socket}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}
      "categorias"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"           -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"                  -> {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}
      "usuarios"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_ofertas"            -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/ofertas")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Seleccionar lista activa ──────────────────────────────────────────────────

  @impl true
  def handle_event("seleccionar_lista", %{"numero" => n_str}, socket) do
    numero = String.to_integer(n_str)
    precios_map = ListasPrecios.get_precios_map(numero)
    {:noreply, assign(socket, numero_activo: numero, precios_map: precios_map, edits: %{}, saved: false)}
  end

  # ── Crear nueva lista ─────────────────────────────────────────────────────────

  @impl true
  def handle_event("crear_lista", %{"numero" => n_str}, socket) do
    case Integer.parse(n_str) do
      {n, ""} when n > 0 ->
        numeros = (socket.assigns.numeros ++ [n]) |> Enum.uniq() |> Enum.sort()
        {:noreply, assign(socket, numeros: numeros, numero_activo: n, precios_map: %{}, edits: %{}, nuevo_numero: "", saved: false)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_nuevo_numero", %{"value" => v}, socket) do
    {:noreply, assign(socket, nuevo_numero: v)}
  end

  # ── Búsqueda de productos ─────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q)}
  end

  # ── Edición de precio en la celda ─────────────────────────────────────────────

  @impl true
  def handle_event("edit_precio", %{"codigo" => codigo, "value" => value}, socket) do
    edits = Map.put(socket.assigns.edits, codigo, value)
    {:noreply, assign(socket, edits: edits, saved: false)}
  end

  # ── Guardar todos los precios editados ────────────────────────────────────────

  @impl true
  def handle_event("guardar", _params, socket) do
    numero = socket.assigns.numero_activo
    edits  = socket.assigns.edits

    precios_list =
      Enum.map(edits, fn {cod, precio} -> %{"producto_codigo" => cod, "precio" => precio} end)

    case ListasPrecios.guardar_lista(numero, precios_list) do
      {:ok, _} ->
        precios_map = ListasPrecios.get_precios_map(numero)
        numeros     = ListasPrecios.numeros_disponibles()
        {:noreply, socket |> assign(precios_map: precios_map, numeros: numeros, edits: %{}, saved: true) |> put_flash(:info, "Lista de precios guardada correctamente")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al guardar precios")}
    end
  end

  # ── Eliminar precio de un producto ────────────────────────────────────────────

  @impl true
  def handle_event("quitar_precio", %{"codigo" => codigo}, socket) do
    ListasPrecios.eliminar_precio(socket.assigns.numero_activo, codigo)
    precios_map = Map.delete(socket.assigns.precios_map, codigo)
    edits       = Map.delete(socket.assigns.edits, codigo)
    {:noreply, assign(socket, precios_map: precios_map, edits: edits, saved: false)}
  end

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-4 space-y-5">

      <!-- Encabezado -->
      <div class="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 class="text-lg font-bold text-gray-900">Listas de Precios</h1>
          <p class="text-xs text-gray-500">Precios por lista para clientes Prettycore</p>
        </div>
        <button
          phx-click="guardar"
          disabled={map_size(@edits) == 0}
          class={"flex items-center gap-2 px-4 py-2 text-sm font-semibold rounded-xl transition-colors #{if @saved, do: "bg-green-500 text-white", else: if map_size(@edits) == 0, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-gray-900 hover:bg-gray-700 text-white"}"}
        >
          <%= if @saved do %>
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
            Guardado
          <% else %>
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"/></svg>
            Guardar <%= if map_size(@edits) > 0, do: "(#{map_size(@edits)})", else: "" %>
          <% end %>
        </button>
      </div>

      <!-- Selector de lista + crear nueva -->
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Lista:</span>
        <%= for n <- @numeros do %>
          <button type="button" phx-click="seleccionar_lista" phx-value-numero={n}
            class={"px-3 py-1.5 rounded-lg text-sm font-semibold transition-colors #{if @numero_activo == n, do: "bg-gray-900 text-white", else: "bg-gray-100 text-gray-600 hover:bg-gray-200"}"}>
            Lista <%= n %>
          </button>
        <% end %>
        <!-- Nueva lista -->
        <form phx-submit="crear_lista" class="flex items-center gap-1.5 ml-2">
          <input type="number" name="numero" value={@nuevo_numero} min="1" max="9999"
            placeholder="Nueva #"
            phx-blur="set_nuevo_numero"
            class="w-20 px-2 py-1.5 text-sm border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900/20" />
          <button type="submit"
            class="px-3 py-1.5 text-sm font-semibold bg-white border border-gray-200 hover:bg-gray-50 rounded-lg transition-colors text-gray-700">
            + Crear
          </button>
        </form>
      </div>

      <!-- Info de cambios pendientes -->
      <%= if map_size(@edits) > 0 do %>
        <div class="bg-amber-50 border border-amber-200 rounded-xl px-4 py-2 flex items-center gap-2">
          <svg class="w-4 h-4 text-amber-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
          <span class="text-xs font-semibold text-amber-700"><%= map_size(@edits) %> precio(s) modificado(s) sin guardar</span>
        </div>
      <% end %>

      <!-- Buscador -->
      <div class="relative w-full sm:max-w-sm">
        <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input type="text" placeholder="Buscar producto..." value={@search}
          phx-keyup="search" name="q" phx-debounce="200"
          class="w-full pl-9 pr-4 py-2 text-sm border border-gray-200 rounded-xl bg-white focus:outline-none focus:ring-2 focus:ring-gray-900/20" />
      </div>

      <!-- Tabla de productos con precios -->
      <%
        filtered =
          if @search != "" do
            s = String.downcase(@search)
            Enum.filter(@productos, fn p ->
              String.contains?(String.downcase(p.descripcion || ""), s) or
              String.contains?(String.downcase(p.codigo || ""), s)
            end)
          else
            @productos
          end
      %>
      <div class="bg-white rounded-2xl border border-gray-100 overflow-hidden overflow-x-auto">
        <table class="w-full text-sm min-w-[520px]">
          <thead>
            <tr class="border-b border-gray-100 bg-gray-50/50">
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Producto</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Código</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Precio público</th>
              <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Precio Lista <%= @numero_activo %></th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-50">
            <%= if Enum.empty?(filtered) do %>
              <tr>
                <td colspan="5" class="py-12 text-center text-gray-400 text-sm">
                  No hay productos nativos. <.link navigate={~p"/admin/productos-nativos"} class="text-gray-900 font-semibold underline">Agregar productos</.link>
                </td>
              </tr>
            <% else %>
              <%= for prod <- filtered do %>
                <%
                  precio_lista = Map.get(@edits, prod.codigo,
                    case Map.get(@precios_map, prod.codigo) do
                      nil -> ""
                      f   -> :erlang.float_to_binary(f * 1.0, decimals: 2)
                    end)
                  tiene_precio = Map.has_key?(@precios_map, prod.codigo) or Map.has_key?(@edits, prod.codigo)
                %>
                <tr class="hover:bg-gray-50/40 transition-colors">
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-3">
                      <%= if prod.imagen_url && prod.imagen_url != "" do %>
                        <img src={prod.imagen_url} class="w-8 h-8 rounded-lg object-cover flex-shrink-0 bg-gray-100" />
                      <% else %>
                        <div class="w-8 h-8 rounded-lg bg-gray-100 flex items-center justify-center flex-shrink-0">
                          <svg class="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                        </div>
                      <% end %>
                      <span class="font-medium text-gray-900 text-xs line-clamp-2"><%= prod.descripcion %></span>
                    </div>
                  </td>
                  <td class="px-4 py-3">
                    <span class="font-mono text-xs bg-gray-100 px-1.5 py-0.5 rounded text-gray-600"><%= prod.codigo %></span>
                  </td>
                  <td class="px-4 py-3 text-xs text-gray-500">
                    $<%= :erlang.float_to_binary(prod.precio_base * 1.0, decimals: 2) %>
                  </td>
                  <td class="px-4 py-3">
                    <div class="relative max-w-[120px]">
                      <span class="absolute left-2.5 top-1/2 -translate-y-1/2 text-gray-400 text-xs font-medium pointer-events-none">$</span>
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={precio_lista}
                        phx-blur="edit_precio"
                        phx-value-codigo={prod.codigo}
                        placeholder="—"
                        class={"w-full pl-6 pr-2 py-1.5 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-gray-900/20 transition-colors #{if Map.has_key?(@edits, prod.codigo), do: "border-amber-300 bg-amber-50", else: "border-gray-200 bg-white"}"}
                      />
                    </div>
                  </td>
                  <td class="px-4 py-3">
                    <%= if tiene_precio do %>
                      <button type="button" phx-click="quitar_precio" phx-value-codigo={prod.codigo}
                        title="Quitar precio de esta lista"
                        class="p-1 text-gray-300 hover:text-red-500 transition-colors rounded">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>

      <p class="text-xs text-gray-400 text-right">
        <%= length(filtered) %> producto(s) — Lista <%= @numero_activo %>
        <%= if map_size(@precios_map) > 0, do: " · #{map_size(@precios_map)} con precio asignado", else: "" %>
      </p>
    </div>
    """
  end
end
