defmodule PrettycoreWeb.StockLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Sucursales
  alias Prettycore.ProductosNativos
  alias Prettycore.StockSucursal

  @impl true
  def mount(_params, _session, socket) do
    sucursales = Sucursales.list_activas()
    sucursal_activa = List.first(sucursales)
    productos = ProductosNativos.list_todos()

    stock_map =
      if sucursal_activa, do: StockSucursal.get_stock_map(sucursal_activa.numero), else: %{}

    {:ok,
     socket
     |> assign(:current_page, "stock")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:sidebar_open, true)
     |> assign(:sucursales, sucursales)
     |> assign(:sucursal_activa, sucursal_activa)
     |> assign(:productos, productos)
     |> assign(:stock_map, stock_map)
     |> assign(:edits, %{})
     |> assign(:guardando, false)
     |> assign(:saved, false)
     |> assign(:search, "")}
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
      "stock"                      -> {:noreply, socket}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_ofertas"            -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/ofertas")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Selección de sucursal ─────────────────────────────────────────────────────

  @impl true
  def handle_event("seleccionar_sucursal", %{"numero" => n_str}, socket) do
    numero = String.to_integer(n_str)
    sucursal = Enum.find(socket.assigns.sucursales, &(&1.numero == numero))
    stock_map = StockSucursal.get_stock_map(numero)
    {:noreply, socket
     |> assign(:sucursal_activa, sucursal)
     |> assign(:stock_map, stock_map)
     |> assign(:edits, %{})
     |> assign(:saved, false)}
  end

  # ── Edición de cantidad ───────────────────────────────────────────────────────

  @impl true
  def handle_event("editar_cantidad", %{"codigo" => codigo, "valor" => valor}, socket) do
    edits = Map.put(socket.assigns.edits, codigo, valor)
    {:noreply, assign(socket, :edits, edits)}
  end

  # ── Guardar ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar_stock", _, socket) do
    %{sucursal_activa: sucursal, edits: edits} = socket.assigns

    if sucursal do
      StockSucursal.guardar_stock(sucursal.numero, edits)
      stock_map = StockSucursal.get_stock_map(sucursal.numero)
      {:noreply, socket
       |> assign(:stock_map, stock_map)
       |> assign(:edits, %{})
       |> assign(:saved, true)}
    else
      {:noreply, socket}
    end
  end

  # ── Búsqueda ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search, q)}
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp cantidad_actual(stock_map, edits, codigo) do
    cond do
      Map.has_key?(edits, codigo) -> edits[codigo]
      Map.has_key?(stock_map, codigo) -> stock_map[codigo]
      true -> 0
    end
  end

  defp productos_filtrados(productos, ""), do: productos
  defp productos_filtrados(productos, q) do
    q = String.downcase(q)
    Enum.filter(productos, fn p ->
      String.contains?(String.downcase(p.descripcion), q) or
      String.contains?(String.downcase(p.codigo), q)
    end)
  end

  # ── Template ─────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-6 min-w-0">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-gray-900">Stock por Sucursal</h1>
        <%= if @saved do %>
          <span class="text-sm text-green-600 font-medium">¡Guardado!</span>
        <% end %>
      </div>

      <%= if @sucursales == [] do %>
        <div class="bg-yellow-50 border border-yellow-200 rounded-2xl p-6 text-center text-sm text-yellow-700">
          No hay sucursales activas. Primero crea sucursales en la sección
          <a href="/admin/sucursales" class="underline font-medium">Sucursales</a>.
        </div>
      <% else %>
        <!-- Selector de sucursal -->
        <div class="flex items-center gap-3 mb-5">
          <span class="text-sm font-medium text-gray-600">Sucursal:</span>
          <div class="flex gap-2 flex-wrap">
            <%= for s <- @sucursales do %>
              <button
                phx-click="seleccionar_sucursal"
                phx-value-numero={s.numero}
                class={"px-3 py-1.5 text-sm font-medium rounded-xl border transition " <>
                  if @sucursal_activa && @sucursal_activa.numero == s.numero,
                    do: "bg-gray-900 text-white border-gray-900",
                    else: "border-gray-200 text-gray-700 hover:bg-gray-50"}
              >
                <%= s.numero %> – <%= s.nombre %>
              </button>
            <% end %>
          </div>
        </div>

        <%= if @sucursal_activa do %>
          <!-- Búsqueda -->
          <div class="mb-4">
            <input
              type="text"
              phx-change="search"
              name="q"
              value={@search}
              placeholder="Buscar producto..."
              class="w-full max-w-xs text-sm rounded-xl border border-gray-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
            />
          </div>

          <!-- Tabla de productos con stock -->
          <div class="bg-white rounded-2xl border border-gray-200 overflow-hidden overflow-x-auto">
            <table class="w-full text-sm min-w-[500px]">
              <thead class="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Código</th>
                  <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase">Descripción</th>
                  <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase w-32">
                    Stock – Suc. <%= @sucursal_activa.numero %>
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <%= for p <- productos_filtrados(@productos, @search) do %>
                  <tr class="hover:bg-gray-50 transition">
                    <td class="px-4 py-3 font-mono text-xs text-gray-500"><%= p.codigo %></td>
                    <td class="px-4 py-3 text-gray-900"><%= p.descripcion %></td>
                    <td class="px-4 py-3 text-center">
                      <form phx-change="editar_cantidad">
                        <input type="hidden" name="codigo" value={p.codigo} />
                        <input
                          type="number"
                          min="0"
                          value={cantidad_actual(@stock_map, @edits, p.codigo)}
                          name="valor"
                          class="w-24 text-center text-sm rounded-lg border border-gray-300 px-2 py-1 focus:outline-none focus:ring-2 focus:ring-gray-900"
                        />
                      </form>
                    </td>
                  </tr>
                <% end %>
                <%= if productos_filtrados(@productos, @search) == [] do %>
                  <tr>
                    <td colspan="3" class="px-4 py-8 text-center text-sm text-gray-400">
                      No hay productos registrados.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <div class="mt-4 flex justify-end">
            <button
              phx-click="guardar_stock"
              class="px-5 py-2.5 bg-gray-900 text-white text-sm font-medium rounded-xl hover:bg-gray-700 transition"
            >
              Guardar Stock
            </button>
          </div>
        <% end %>
      <% end %>
    </div>
    </div>
    """
  end
end
