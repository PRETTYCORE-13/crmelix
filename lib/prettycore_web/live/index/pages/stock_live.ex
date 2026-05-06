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

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "stock")
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

  # ── Edición de cantidad (auto-save al blur) ───────────────────────────────────

  @impl true
  def handle_event("guardar_cantidad", %{"codigo" => codigo, "value" => valor}, socket) do
    if socket.assigns.sucursal_activa do
      numero = socket.assigns.sucursal_activa.numero
      cantidad = case Integer.parse(to_string(valor)) do
        {n, _} when n >= 0 -> n
        _ -> 0
      end
      StockSucursal.upsert_stock(codigo, numero, cantidad)
      stock_map = Map.put(socket.assigns.stock_map, codigo, cantidad)
      {:noreply, assign(socket, stock_map: stock_map, saved: true)}
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
    words = q |> String.downcase() |> String.split(~r/\s+/, trim: true)
    Enum.filter(productos, fn p ->
      desc = String.downcase(p.descripcion || "")
      cod  = String.downcase(p.codigo || "")
      Enum.all?(words, fn w -> String.contains?(desc, w) or String.contains?(cod, w) end)
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
            <table class="w-full text-sm min-w-[560px]">
              <thead class="bg-gray-50 border-b border-gray-200">
                <tr>
                  <th class="px-4 py-3 w-14"></th>
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
                    <td class="px-3 py-2 w-14">
                      <%= if p.imagen_url && p.imagen_url != "" do %>
                        <img
                          src={p.imagen_url}
                          alt={p.descripcion}
                          class="w-10 h-10 object-contain rounded-lg bg-gray-50"
                        />
                      <% else %>
                        <div class="w-10 h-10 rounded-lg bg-gray-100 flex items-center justify-center">
                          <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3 20.25h18A.75.75 0 0021.75 19.5v-15A.75.75 0 0021 3.75H3A.75.75 0 002.25 4.5v15c0 .414.336.75.75.75z"/>
                          </svg>
                        </div>
                      <% end %>
                    </td>
                    <td class="px-4 py-2 font-mono text-xs text-gray-500"><%= p.codigo %></td>
                    <td class="px-4 py-2 text-gray-900"><%= p.descripcion %></td>
                    <td class="px-4 py-2 text-center">
                      <input
                        type="number"
                        min="0"
                        value={cantidad_actual(@stock_map, @edits, p.codigo)}
                        phx-blur="guardar_cantidad"
                        phx-value-codigo={p.codigo}
                        class="w-24 text-center text-sm rounded-lg border border-gray-300 px-2 py-1 focus:outline-none focus:ring-2 focus:ring-gray-900"
                      />
                    </td>
                  </tr>
                <% end %>
                <%= if productos_filtrados(@productos, @search) == [] do %>
                  <tr>
                    <td colspan="4" class="px-4 py-8 text-center text-sm text-gray-400">
                      No hay productos registrados.
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <%= if @saved do %>
            <div class="mt-4 flex justify-end">
              <span class="inline-flex items-center gap-1.5 text-sm font-medium text-green-600">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                Guardado automáticamente
              </span>
            </div>
          <% end %>
        <% end %>
      <% end %>
    </div>
    </div>
    """
  end
end
