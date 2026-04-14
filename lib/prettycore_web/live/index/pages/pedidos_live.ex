defmodule PrettycoreWeb.PedidosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Pedidos
  alias Prettycore.Auth

  @estados_color %{
    "pendiente"              => "bg-yellow-100 text-yellow-700",
    "procesando"             => "bg-blue-100 text-blue-700",
    "enviado"                => "bg-purple-100 text-purple-700",
    "entregado"              => "bg-green-100 text-green-700",
    "cancelado"              => "bg-red-100 text-red-500",
    "cancelacion_solicitada" => "bg-orange-100 text-orange-700"
  }

  @impl true
  def mount(_params, _session, socket) do
    role    = socket.assigns[:user_role]
    user_id = socket.assigns[:current_user_id]

    socket =
      socket
      |> assign(:current_page, "pedidos")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
      |> assign(:pedidos, [])
      |> assign(:loading, true)
      |> assign(:estados_color, @estados_color)

    if connected?(socket) do
      send(self(), {:load_pedidos, user_id, role})
    end

    if role == "sysadmin" do
      {:ok, socket, layout: false}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info({:load_pedidos, user_id, role}, socket) do
    pedidos = Pedidos.list_pedidos(user_id, role)
    {:noreply, assign(socket, pedidos: pedidos, loading: false)}
  end

  @impl true
  def handle_event("cambiar_estado", %{"id" => id, "estado" => estado}, socket) do
    case Pedidos.cambiar_estado(id, estado) do
      {:ok, _} ->
        pedidos = Pedidos.list_pedidos(socket.assigns.current_user_id, socket.assigns.user_role)
        {:noreply, socket |> assign(pedidos: pedidos) |> put_flash(:info, "Estado actualizado a \"#{String.capitalize(estado)}\"")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo cambiar el estado")}
    end
  end

  @impl true
  def handle_event("solicitar_cancelacion", %{"id" => id}, socket) do
    case Pedidos.solicitar_cancelacion(id) do
      {:ok, _} ->
        pedidos = Pedidos.list_pedidos(socket.assigns.current_user_id, socket.assigns.user_role)
        {:noreply, socket |> assign(pedidos: pedidos) |> put_flash(:info, "Solicitud de cancelación enviada. El equipo la revisará.")}
      {:error, :no_cancelable} ->
        {:noreply, put_flash(socket, :error, "Este pedido ya no puede cancelarse")}
      _ ->
        {:noreply, put_flash(socket, :error, "Error al solicitar cancelación")}
    end
  end

  @impl true
  def handle_event("cancelar", %{"id" => id}, socket) do
    case Pedidos.cancelar(id) do
      {:ok, _} ->
        pedidos = Pedidos.list_pedidos(socket.assigns.current_user_id, socket.assigns.user_role)
        {:noreply, socket |> assign(pedidos: pedidos) |> put_flash(:info, "Pedido cancelado")}
      {:error, :no_cancelable} ->
        {:noreply, put_flash(socket, :error, "Solo se pueden cancelar pedidos pendientes o en proceso")}
      _ ->
        {:noreply, put_flash(socket, :error, "Error al cancelar pedido")}
    end
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"    -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"            -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, socket}
      "categorias"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"           -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"                  -> {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}
      "usuarios"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      _                            -> {:noreply, socket}
    end
  end

  @impl true
  def render(%{user_role: "sysadmin"} = assigns) do
    ~H"""
    <PrettycoreWeb.SysAdminLayout.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <.pedidos_page {assigns} />
    </PrettycoreWeb.SysAdminLayout.sidebar>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.pedidos_page {assigns} />
    """
  end

  defp pedidos_page(assigns) do
    ~H"""
    <section class="min-h-screen bg-gray-50">
      <header class="sticky top-0 z-40 bg-gray-50/95 backdrop-blur-sm border-b border-gray-200 px-4 sm:px-6 py-3">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Pedidos</h1>
            <p class="text-sm text-gray-500 mt-0.5">Historial de pedidos realizados</p>
          </div>
          <%= if not @loading do %>
            <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-white text-gray-500 border border-gray-200">
              <%= length(@pedidos) %> pedidos
            </span>
          <% end %>
        </div>
      </header>

      <div class="px-4 sm:px-6 py-6">
        <%= if @loading do %>
          <div class="flex flex-col items-center justify-center py-24 text-gray-400">
            <svg class="animate-spin h-8 w-8 mb-3 text-purple-500" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
            </svg>
            <p class="text-sm">Cargando pedidos...</p>
          </div>
        <% else %>
          <%= if @pedidos == [] do %>
            <div class="flex flex-col items-center justify-center py-24 text-gray-400">
              <svg class="w-16 h-16 mb-4 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
              </svg>
              <p class="text-sm font-medium">No hay pedidos aún</p>
              <p class="text-xs mt-1">Los pedidos aparecerán aquí al realizarlos desde la tienda</p>
            </div>
          <% else %>
            <div class="space-y-4 max-w-4xl mx-auto">
              <%= for pedido <- @pedidos do %>
                <%
                  total_pzas = Enum.sum(Enum.map(pedido.items, & &1.cantidad))
                  total_precio = Enum.reduce(pedido.items, 0.0, fn i, acc -> acc + i.precio_unitario * i.cantidad end)
                  color = Map.get(@estados_color, pedido.estado, "bg-gray-100 text-gray-500")
                  fecha = Calendar.strftime(pedido.inserted_at, "%d/%m/%Y %H:%M")
                %>
                <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
                  <!-- Cabecera del pedido -->
                  <div class="flex items-center justify-between px-5 py-4 border-b border-gray-50">
                    <div class="flex items-center gap-3">
                      <div class="w-9 h-9 rounded-xl bg-purple-50 flex items-center justify-center">
                        <svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                        </svg>
                      </div>
                      <div>
                        <p class="text-sm font-semibold text-gray-900">Pedido <span class="font-mono text-xs text-gray-400"><%= String.slice(pedido.id, 0, 8) %>...</span></p>
                        <p class="text-xs text-gray-400"><%= fecha %></p>
                      </div>
                    </div>
                    <div class="flex items-center gap-2">
                      <span class={"inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold #{color}"}>
                        <%= case pedido.estado do
                          "cancelacion_solicitada" -> "Cancelación solicitada"
                          e -> String.capitalize(e)
                        end %>
                      </span>
                      <!-- Admin: aprobar/declinar cancelación solicitada -->
                      <%= if @user_role in ["admin", "sysadmin"] and pedido.estado == "cancelacion_solicitada" do %>
                        <div class="flex items-center gap-1.5">
                          <button
                            phx-click="cancelar"
                            phx-value-id={pedido.id}
                            data-confirm="¿Aprobar cancelación del pedido?"
                            class="text-xs font-semibold px-2.5 py-1 rounded-lg bg-red-100 text-red-600 hover:bg-red-200 transition-colors"
                          >
                            Aprobar cancelación
                          </button>
                          <button
                            phx-click="cambiar_estado"
                            phx-value-id={pedido.id}
                            phx-value-estado="pendiente"
                            data-confirm="¿Declinar la solicitud y regresar a pendiente?"
                            class="text-xs font-semibold px-2.5 py-1 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200 transition-colors"
                          >
                            Declinar
                          </button>
                        </div>
                      <% end %>
                      <!-- Admin: cambio de estado normal (cuando no es cancelacion_solicitada) -->
                      <%= if @user_role in ["admin", "sysadmin"] and pedido.estado != "cancelacion_solicitada" do %>
                        <select
                          phx-change="cambiar_estado"
                          name="estado"
                          phx-value-id={pedido.id}
                          class="text-xs border border-gray-200 rounded-lg px-2 py-1 text-gray-600 bg-white focus:ring-1 focus:ring-purple-400 cursor-pointer"
                        >
                          <%= for estado <- Prettycore.Pedidos.Pedido.estados() do %>
                            <option value={estado} selected={estado == pedido.estado}><%= String.capitalize(estado) %></option>
                          <% end %>
                        </select>
                      <% end %>
                      <!-- Cliente: solicitar cancelación si está pendiente o procesando -->
                      <%= if @user_role not in ["admin", "sysadmin"] and pedido.estado in ["pendiente", "procesando"] do %>
                        <button
                          phx-click="solicitar_cancelacion"
                          phx-value-id={pedido.id}
                          data-confirm="¿Solicitar cancelación de este pedido?"
                          class="text-xs text-red-400 hover:text-red-600 transition-colors"
                        >
                          Cancelar
                        </button>
                      <% end %>
                    </div>
                  </div>

                  <!-- Items del pedido -->
                  <div class="px-5 py-3 space-y-2">
                    <%= for item <- pedido.items do %>
                      <div class="flex items-center justify-between text-sm">
                        <div class="flex items-center gap-2">
                          <span class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-gray-100 text-xs font-bold text-gray-600"><%= item.cantidad %>×</span>
                          <span class="text-gray-700"><%= item.descripcion || item.producto_codigo %></span>
                          <span class="text-xs text-gray-400 font-mono"><%= item.producto_codigo %></span>
                        </div>
                        <%= if item.precio_unitario > 0 do %>
                          <span class="text-xs font-semibold text-gray-900">$<%= :erlang.float_to_binary(item.precio_unitario * item.cantidad / 1, decimals: 2) %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <!-- Pie del pedido -->
                  <div class="flex items-center justify-between px-5 py-3 bg-gray-50 border-t border-gray-100">
                    <span class="text-xs text-gray-400"><%= total_pzas %> pzas · <%= length(pedido.items) %> productos</span>
                    <%= if total_precio > 0 do %>
                      <span class="text-sm font-bold text-gray-900">Total: $<%= :erlang.float_to_binary(total_precio / 1, decimals: 2) %></span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </section>
    """
  end
end
