defmodule PrettycoreWeb.PedidosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Pedidos
  alias Prettycore.Auth
  alias Prettycore.ClientesNativos
  alias Prettycore.Sucursales
  alias Prettycore.Notificaciones
  alias Prettycore.SysAdmin

  @estados_color %{
    "pendiente"              => "bg-yellow-400 text-black",
    "procesando"             => "bg-blue-600 text-white",
    "enviado"                => "bg-violet-600 text-white",
    "entregado"              => "bg-green-600 text-white",
    "cancelado"              => "bg-red-600 text-white",
    "cancelacion_solicitada" => "bg-orange-500 text-white"
  }

  @estados_accent %{
    "pendiente"              => "bg-yellow-400",
    "procesando"             => "bg-blue-600",
    "enviado"                => "bg-violet-600",
    "entregado"              => "bg-green-600",
    "cancelado"              => "bg-red-600",
    "cancelacion_solicitada" => "bg-orange-500"
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
      |> assign(:estados_accent, @estados_accent)
      |> assign(:clientes_map, %{})
      |> assign(:expanded_pedido_id, nil)
      |> assign(:search_pedidos, "")
      |> assign(:detalle_pedido_id, nil)
      |> assign(:detalle_imgs, %{})
      |> assign(:open_pedido_id, nil)
      |> assign(:timezone, SysAdmin.get_config().timezone || "America/Mexico_City")

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Prettycore.PubSub, "pedidos:updates")
      send(self(), {:load_pedidos, user_id, role})
    end

    if role == "sysadmin" do
      {:ok, socket, layout: false}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"pedido_id" => id}, _uri, socket) do
    {:noreply, assign(socket, :open_pedido_id, id)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_pedidos, user_id, role}, socket) do
    pedidos = Pedidos.list_pedidos(user_id, role)
    clientes_map = build_clientes_map(pedidos)
    socket = assign(socket, pedidos: pedidos, clientes_map: clientes_map, loading: false)
    socket = case socket.assigns.open_pedido_id do
      nil -> socket
      id  -> abrir_detalle(socket, id)
    end
    {:noreply, socket}
  end

  def handle_info(:pedidos_updated, socket) do
    pedidos = Pedidos.list_pedidos(socket.assigns.current_user_id, socket.assigns.user_role)
    {:noreply, assign(socket, pedidos: pedidos)}
  end

  defp build_clientes_map(pedidos) do
    sucursales_map =
      Sucursales.list_todas()
      |> Map.new(fn s -> {s.numero, s.nombre} end)

    pedidos
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn uid, acc ->
      info =
        case Auth.get_user(uid) do
          nil ->
            case ClientesNativos.get(uid) do
              nil -> nil
              c   ->
                sucursal_nombre =
                  if c.sucursal_numero,
                    do: Map.get(sucursales_map, c.sucursal_numero, "Suc. #{c.sucursal_numero}"),
                    else: nil
                %{nombre: c.nombre, username: c.username, email: c.email,
                  telefono: c.telefono, rfc: c.rfc, direccion: c.direccion,
                  notas: c.notas, rol: "Cliente", activo: c.activo,
                  lista: "L#{c.lista_precios}", sucursal: sucursal_nombre}
            end
          u ->
            %{nombre: u.username, username: u.username, email: u.email,
              telefono: nil, rfc: nil, direccion: nil, notas: nil,
              rol: String.capitalize(u.role || "user"), activo: u.active,
              lista: nil, sucursal: nil}
        end
      if info, do: Map.put(acc, uid, info), else: acc
    end)
  end

  @impl true
  def handle_event("search_pedidos", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search_pedidos, q)}
  end

  def handle_event("search_pedidos", %{"value" => q}, socket) do
    {:noreply, assign(socket, :search_pedidos, q)}
  end

  @impl true
  def handle_event("toggle_cliente_info", %{"id" => id}, socket) do
    expanded = if socket.assigns.expanded_pedido_id == id, do: nil, else: id
    {:noreply, assign(socket, :expanded_pedido_id, expanded)}
  end

  @impl true
  def handle_event("ver_detalle", %{"id" => id}, socket) do
    {:noreply, abrir_detalle(socket, id)}
  end

  defp abrir_detalle(socket, id) do
    import Ecto.Query
    pedido = Enum.find(socket.assigns.pedidos, &(&1.id == id))
    imgs =
      if pedido do
        codigos = Enum.map(pedido.items, & &1.producto_codigo)
        frog_imgs =
          Prettycore.PsqlRepo.all(
            from p in Prettycore.Productos.Producto,
              where: p.codigo in ^codigos,
              select: {p.codigo, p.imagen_url}
          ) |> Map.new()
        nativo_imgs =
          Prettycore.PsqlRepo.all(
            from p in Prettycore.ProductosNativos.ProductoNativo,
              where: p.codigo in ^codigos,
              select: {p.codigo, p.imagen_url}
          ) |> Map.new()
        Map.merge(frog_imgs, nativo_imgs)
      else
        %{}
      end
    assign(socket, detalle_pedido_id: id, detalle_imgs: imgs, open_pedido_id: nil)
  end

  @impl true
  def handle_event("cerrar_detalle", _, socket) do
    {:noreply, assign(socket, detalle_pedido_id: nil, detalle_imgs: %{})}
  end

  @impl true
  def handle_event("cambiar_estado", %{"id" => id, "estado" => estado}, socket) do
    pedido = Pedidos.get_pedido(id)
    if is_nil(pedido) or pedido.estado == estado do
      {:noreply, socket}
    else
      case Pedidos.cambiar_estado(id, estado) do
        {:ok, _} ->
          if pedido do
            {titulo, msg, tipo} = case estado do
              "procesando" -> {"Pedido en proceso",    "Tu pedido está siendo preparado.",         "info"}
              "enviado"    -> {"Pedido enviado",        "Tu pedido ha sido enviado.",               "success"}
              "entregado"  -> {"Pedido entregado",      "Tu pedido fue entregado. ¡Gracias!",       "success"}
              "cancelado"  -> {"Pedido cancelado",      "Tu pedido fue cancelado por el equipo.",   "warning"}
              _            -> {"Pedido actualizado",    "El estado de tu pedido fue actualizado.",  "info"}
            end
            Notificaciones.crear(pedido.user_id, %{titulo: titulo, mensaje: msg, tipo: tipo, pedido_id: pedido.id})
          end
          Phoenix.PubSub.broadcast(Prettycore.PubSub, "pedidos:updates", :pedidos_updated)
          pedidos = Pedidos.list_pedidos(socket.assigns.current_user_id, socket.assigns.user_role)
          {:noreply, socket |> assign(pedidos: pedidos) |> put_flash(:info, "Estado actualizado a \"#{String.capitalize(estado)}\"")}
        {:error, :transicion_invalida} ->
          {:noreply, put_flash(socket, :error, "Transición no permitida (ej: un pedido entregado o cancelado no puede modificarse)")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "No se pudo cambiar el estado")}
      end
    end
  end

  @impl true
  def handle_event("solicitar_cancelacion", %{"id" => id}, socket) do
    case Pedidos.solicitar_cancelacion(id) do
      {:ok, _} ->
        Notificaciones.crear(socket.assigns.current_user_id, %{
          titulo: "Cancelación solicitada",
          mensaje: "Tu solicitud de cancelación fue registrada y está pendiente de aprobación.",
          tipo: "warning",
          pedido_id: id
        })
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
    pedido = Pedidos.get_pedido(id)
    case Pedidos.cancelar(id) do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(Prettycore.PubSub, "pedidos:updates", :pedidos_updated)
        if pedido do
          Notificaciones.crear(pedido.user_id, %{
            titulo: "Pedido cancelado",
            mensaje: "Tu pedido fue cancelado.",
            tipo: "warning",
            pedido_id: pedido.id
          })
        end
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
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "pedidos")
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
    <%= if @detalle_pedido_id do %>
      <.detalle_view {assigns} />
    <% else %>
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

      <!-- Buscador -->
      <div class="px-4 sm:px-6 pt-4 pb-0">
        <div class="relative max-w-4xl mx-auto">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            placeholder="Buscar por # pedido, sucursal, teléfono o correo..."
            value={@search_pedidos}
            phx-keyup="search_pedidos"
            phx-change="search_pedidos"
            phx-debounce="200"
            name="q"
            class="w-full pl-9 pr-4 py-2.5 text-sm border border-gray-200 rounded-xl bg-white focus:outline-none focus:ring-2 focus:ring-indigo-400/40 shadow-sm"
          />
          <%= if @search_pedidos != "" do %>
            <button
              phx-click="search_pedidos"
              phx-value-q=""
              class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          <% end %>
        </div>
      </div>

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
            <%
              pedidos_filtrados =
                if @search_pedidos == "" do
                  @pedidos
                else
                  q = String.downcase(@search_pedidos)
                  Enum.filter(@pedidos, fn p ->
                    info = Map.get(@clientes_map, p.user_id)
                    id_match = String.contains?(String.downcase(p.id), q)
                    cliente_match =
                      if info do
                        Enum.any?(
                          [info.nombre, info.username, info.email, info.telefono, info.sucursal],
                          fn campo -> campo && String.contains?(String.downcase(campo), q) end
                        )
                      else
                        false
                      end
                    id_match or cliente_match
                  end)
                end
            %>
            <div class="space-y-4 max-w-4xl mx-auto">
              <%= if Enum.empty?(pedidos_filtrados) do %>
                <div class="flex flex-col items-center justify-center py-16 text-gray-400">
                  <svg class="w-12 h-12 mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                  <p class="text-sm font-medium">Sin resultados para "<%= @search_pedidos %>"</p>
                </div>
              <% end %>
              <%= for pedido <- pedidos_filtrados do %>
                <%
                  total_pzas = Enum.sum(Enum.map(pedido.items, & &1.cantidad))
                  total_precio = Enum.reduce(pedido.items, 0.0, fn i, acc -> acc + i.precio_unitario * i.cantidad end)
                  color = Map.get(@estados_color, pedido.estado, "bg-gray-100 text-gray-500")
                  fecha = format_fecha(pedido.inserted_at, @timezone)
                  cliente_info = Map.get(@clientes_map, pedido.user_id)
                  expandido = @expanded_pedido_id == pedido.id
                %>
                <div class="bg-white rounded-xl border border-gray-200 shadow-md overflow-hidden relative">
                  <!-- Franja de color izquierda según estado -->
                  <div class={"absolute left-0 top-0 bottom-0 w-1 #{Map.get(@estados_accent, pedido.estado, "bg-gray-400")}"}></div>

                  <!-- Cabecera del pedido -->
                  <div class="pl-5 pr-4 sm:pr-5 pt-4 pb-3 space-y-2.5">
                    <!-- Fila 1: icono + info + visualizar -->
                    <div class="flex items-start justify-between gap-3">
                      <div class="flex items-center gap-3 min-w-0">
                        <div class="w-9 h-9 rounded-lg bg-gray-900 flex items-center justify-center flex-shrink-0">
                          <svg class="w-4 h-4 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                          </svg>
                        </div>
                        <div class="min-w-0">
                          <div class="flex items-center gap-1.5 flex-wrap">
                            <p class="text-sm font-bold text-black tracking-tight">Pedido <span class="font-mono text-xs text-gray-400 font-normal"><%= String.slice(pedido.id, 0, 8) %>...</span></p>
                            <button type="button"
                              onclick={"navigator.clipboard.writeText('#{pedido.id}');this.querySelector('.ic').classList.add('hidden');this.querySelector('.ick').classList.remove('hidden');setTimeout(()=>{this.querySelector('.ic').classList.remove('hidden');this.querySelector('.ick').classList.add('hidden')},1500)"}
                              class="text-gray-300 hover:text-black transition-colors" title="Copiar ID completo">
                              <svg class="ic w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                              <svg class="ick w-3.5 h-3.5 hidden text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                            </button>
                          </div>
                          <div class="flex items-center gap-1.5 mt-0.5 flex-wrap">
                            <p class="text-xs text-gray-500"><%= fecha %></p>
                            <%= if cliente_info do %>
                              <span class="text-gray-300">·</span>
                              <p class="text-xs font-bold text-black truncate"><%= cliente_info.nombre %></p>
                            <% end %>
                          </div>
                        </div>
                      </div>
                      <!-- Botón Visualizar -->
                      <button
                        phx-click="ver_detalle"
                        phx-value-id={pedido.id}
                        class="flex items-center gap-1.5 text-xs font-bold px-3 py-1.5 rounded-lg bg-black hover:bg-gray-700 text-white transition-colors flex-shrink-0"
                      >
                        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                        <span class="hidden sm:inline">Visualizar</span>
                      </button>
                    </div>
                    <!-- Fila 2: estado + método de pago + controles -->
                    <div class="flex items-center gap-2 flex-wrap">
                      <span class={"inline-flex items-center px-2.5 py-1 rounded-md text-xs font-bold #{color}"}>
                        <%= case pedido.estado do
                          "cancelacion_solicitada" -> "Cancelación sol."
                          e -> String.capitalize(e)
                        end %>
                      </span>
                      <span class={"inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-xs font-bold #{if pedido.metodo_pago == "credito", do: "bg-blue-600 text-white", else: "bg-gray-900 text-white"}"}>
                        <%= if pedido.metodo_pago == "credito" do %>
                          <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/></svg>
                          Crédito
                        <% else %>
                          <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"/></svg>
                          Contado
                        <% end %>
                      </span>
                      <!-- Admin: aprobar/declinar cancelación solicitada -->
                      <%= if @user_role in ["admin", "sysadmin", "oficina"] and pedido.estado == "cancelacion_solicitada" do %>
                        <button
                          phx-click="cancelar"
                          phx-value-id={pedido.id}
                          data-confirm="¿Aprobar cancelación del pedido?"
                          class="text-xs font-bold px-2.5 py-1 rounded-md bg-red-600 text-white hover:bg-red-700 transition-colors"
                        >Aprobar</button>
                        <button
                          phx-click="cambiar_estado"
                          phx-value-id={pedido.id}
                          phx-value-estado="pendiente"
                          data-confirm="¿Declinar la solicitud y regresar a pendiente?"
                          class="text-xs font-bold px-2.5 py-1 rounded-md bg-gray-800 text-white hover:bg-gray-700 transition-colors"
                        >Declinar</button>
                      <% end %>
                      <!-- Admin: cambio de estado normal -->
                      <%= if @user_role in ["admin", "sysadmin", "oficina"] and pedido.estado != "cancelacion_solicitada" do %>
                        <form phx-change="cambiar_estado">
                          <input type="hidden" name="id" value={pedido.id} />
                          <select
                            name="estado"
                            class="text-xs border-2 border-gray-900 rounded-md px-2 py-1 text-black font-bold bg-white focus:ring-2 focus:ring-black cursor-pointer"
                          >
                            <%= for estado <- Prettycore.Pedidos.Pedido.estados() do %>
                              <option value={estado} selected={estado == pedido.estado}><%= String.capitalize(estado) %></option>
                            <% end %>
                          </select>
                        </form>
                      <% end %>
                      <!-- Cliente: solicitar cancelación -->
                      <%= if @user_role not in ["admin", "sysadmin", "oficina"] and pedido.estado in ["pendiente", "procesando"] do %>
                        <button
                          phx-click="solicitar_cancelacion"
                          phx-value-id={pedido.id}
                          data-confirm="¿Solicitar cancelación de este pedido?"
                          class="text-xs font-bold text-red-600 hover:text-red-800 transition-colors"
                        >Cancelar</button>
                      <% end %>
                    </div>
                  </div>

                  <!-- Items del pedido -->
                  <div class="px-4 sm:px-5 py-3 space-y-1.5 border-t border-gray-100">
                    <%= for item <- pedido.items do %>
                      <div class="flex items-center justify-between text-sm gap-2">
                        <div class="flex items-center gap-2 min-w-0">
                          <span class="inline-flex items-center justify-center w-6 h-6 rounded bg-gray-900 text-xs font-bold text-white flex-shrink-0"><%= item.cantidad %>×</span>
                          <span class="text-gray-800 truncate font-medium"><%= item.descripcion || item.producto_codigo %></span>
                          <span class="text-xs text-gray-400 font-mono hidden sm:inline flex-shrink-0"><%= item.producto_codigo %></span>
                        </div>
                        <%= if item.precio_unitario > 0 do %>
                          <span class="text-sm font-bold text-black flex-shrink-0">$<%= :erlang.float_to_binary(item.precio_unitario * item.cantidad / 1, decimals: 2) %></span>
                        <% end %>
                      </div>
                    <% end %>
                  </div>

                  <!-- Pie del pedido -->
                  <div class="flex items-center justify-between px-4 sm:px-5 py-2.5 bg-white border-t border-gray-100">
                    <span class="text-xs text-gray-400"><%= total_pzas %> pzas · <%= length(pedido.items) %> productos</span>
                    <%= if total_precio > 0 do %>
                      <span class="text-sm font-bold text-black">Total: $<%= :erlang.float_to_binary(total_precio / 1, decimals: 2) %></span>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
    </section>
    <% end %>
    """
  end

  defp detalle_view(assigns) do
    ~H"""
    <%
      pedido       = Enum.find(@pedidos, &(&1.id == @detalle_pedido_id))
      cliente      = if pedido, do: Map.get(@clientes_map, pedido.user_id), else: nil
      color        = if pedido, do: Map.get(@estados_color, pedido.estado, "bg-gray-100 text-gray-500"), else: ""
      fecha        = if pedido, do: format_fecha(pedido.inserted_at, @timezone), else: ""
      total_precio = if pedido, do: Enum.reduce(pedido.items, 0.0, fn i, acc -> acc + i.precio_unitario * i.cantidad end), else: 0.0
      total_pzas   = if pedido, do: Enum.sum(Enum.map(pedido.items, & &1.cantidad)), else: 0
    %>
    <section class="min-h-screen bg-gray-50">
      <!-- Header con regresar -->
      <header class="sticky top-0 z-40 bg-white border-b border-gray-200 px-4 sm:px-6 py-3">
        <div class="max-w-4xl mx-auto space-y-2">
          <!-- Fila 1: regresar + título + ID -->
          <div class="flex items-center gap-3">
            <button phx-click="cerrar_detalle"
              class="flex items-center gap-1.5 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors flex-shrink-0">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              Regresar
            </button>
            <div class="h-4 w-px bg-gray-200 flex-shrink-0"></div>
            <div class="flex items-center gap-1.5 flex-1 min-w-0">
              <h1 class="text-sm font-bold text-gray-900 whitespace-nowrap">Detalle</h1>
              <span class="font-mono text-xs text-gray-400 truncate"><%= if pedido, do: String.slice(pedido.id, 0, 8), else: "" %>...</span>
              <button type="button"
                onclick={"navigator.clipboard.writeText('#{if pedido, do: pedido.id, else: ""}');this.querySelector('.ic').classList.add('hidden');this.querySelector('.ick').classList.remove('hidden');setTimeout(()=>{this.querySelector('.ic').classList.remove('hidden');this.querySelector('.ick').classList.add('hidden')},1500)"}
                class="text-gray-300 hover:text-indigo-500 transition-colors flex-shrink-0" title="Copiar ID completo">
                <svg class="ic w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                <svg class="ick w-3.5 h-3.5 hidden text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
              </button>
            </div>
          </div>
          <!-- Fila 2: estado + controles (solo si hay pedido) -->
          <%= if pedido do %>
            <div class="flex items-center gap-2 flex-wrap">
              <span class={"inline-flex items-center px-2.5 py-1 rounded-md text-xs font-bold #{color}"}>
                <%= case pedido.estado do
                  "cancelacion_solicitada" -> "Cancelación sol."
                  e -> String.capitalize(e)
                end %>
              </span>
              <%= if @user_role in ["admin", "sysadmin", "oficina"] and pedido.estado == "cancelacion_solicitada" do %>
                <button phx-click="cancelar" phx-value-id={pedido.id} data-confirm="¿Aprobar cancelación?"
                  class="text-xs font-bold px-2.5 py-1 rounded-md bg-red-600 text-white hover:bg-red-700 transition-colors">Aprobar</button>
                <button phx-click="cambiar_estado" phx-value-id={pedido.id} phx-value-estado="pendiente" data-confirm="¿Declinar?"
                  class="text-xs font-bold px-2.5 py-1 rounded-md bg-gray-800 text-white hover:bg-gray-700 transition-colors">Declinar</button>
              <% end %>
              <%= if @user_role in ["admin", "sysadmin", "oficina"] and pedido.estado != "cancelacion_solicitada" do %>
                <form phx-change="cambiar_estado">
                  <input type="hidden" name="id" value={pedido.id} />
                  <select name="estado"
                    class="text-xs border-2 border-gray-900 rounded-md px-2 py-1 text-black font-bold bg-white focus:ring-2 focus:ring-black cursor-pointer">
                    <%= for estado <- Prettycore.Pedidos.Pedido.estados() do %>
                      <option value={estado} selected={estado == pedido.estado}><%= String.capitalize(estado) %></option>
                    <% end %>
                  </select>
                </form>
              <% end %>
            </div>
          <% end %>
        </div>
      </header>

      <div class="px-4 sm:px-6 py-6 max-w-4xl mx-auto space-y-6">

        <!-- Tarjeta cliente -->
        <%= if cliente do %>
          <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div class="px-5 py-3 border-b border-gray-50 flex items-center gap-2">
              <svg class="w-4 h-4 text-indigo-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg>
              <span class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Datos del cliente</span>
            </div>
            <div class="px-5 py-4">
              <div class="flex items-center gap-3 mb-4">
                <div class={"w-10 h-10 rounded-full flex items-center justify-center text-base font-bold text-white #{if cliente.activo, do: "bg-indigo-500", else: "bg-gray-400"}"}>
                  <%= (String.first(cliente.nombre || "?") || "?") |> String.upcase() %>
                </div>
                <div>
                  <p class="font-bold text-gray-900"><%= cliente.nombre %></p>
                  <div class="flex items-center gap-2 mt-0.5">
                    <span class={"inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold #{if cliente.activo, do: "bg-green-100 text-green-700", else: "bg-red-100 text-red-500"}"}>
                      <%= if cliente.activo, do: "Activo", else: "Inactivo" %>
                    </span>
                    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded-full bg-indigo-100 text-indigo-600"><%= cliente.rol %></span>
                  </div>
                </div>
                <p class="ml-auto text-xs text-gray-400"><%= fecha %></p>
              </div>
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs">
                <div class="flex items-center gap-2 text-gray-500">
                  <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207"/></svg>
                  <span class="text-gray-400 w-16">Usuario</span>
                  <span class="font-semibold text-gray-700 font-mono"><%= cliente.username %></span>
                  <button type="button" data-val={cliente.username} onclick="navigator.clipboard.writeText(this.dataset.val)" class="text-gray-300 hover:text-indigo-500"><svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg></button>
                </div>
                <%= if cliente.email do %>
                  <div class="flex items-center gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
                    <span class="text-gray-400 w-16">Email</span>
                    <span class="font-medium text-gray-700 truncate"><%= cliente.email %></span>
                    <button type="button" data-val={cliente.email} onclick="navigator.clipboard.writeText(this.dataset.val)" class="text-gray-300 hover:text-indigo-500 flex-shrink-0"><svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg></button>
                  </div>
                <% end %>
                <%= if cliente.telefono do %>
                  <div class="flex items-center gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.948V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/></svg>
                    <span class="text-gray-400 w-16">Teléfono</span>
                    <span class="font-medium text-gray-700"><%= cliente.telefono %></span>
                    <button type="button" data-val={cliente.telefono} onclick="navigator.clipboard.writeText(this.dataset.val)" class="text-gray-300 hover:text-indigo-500 flex-shrink-0"><svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg></button>
                  </div>
                <% end %>
                <%= if cliente.rfc && cliente.rfc != "" do %>
                  <div class="flex items-center gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
                    <span class="text-gray-400 w-16">RFC</span>
                    <span class="font-semibold text-gray-700 font-mono"><%= cliente.rfc %></span>
                    <button type="button" data-val={cliente.rfc} onclick="navigator.clipboard.writeText(this.dataset.val)" class="text-gray-300 hover:text-indigo-500 flex-shrink-0"><svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg></button>
                  </div>
                <% end %>
                <%= if cliente.sucursal do %>
                  <div class="flex items-center gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
                    <span class="text-gray-400 w-16">Sucursal</span>
                    <span class="font-semibold text-gray-700"><%= cliente.sucursal %></span>
                  </div>
                <% end %>
                <%= if cliente.lista do %>
                  <div class="flex items-center gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/></svg>
                    <span class="text-gray-400 w-16">Lista</span>
                    <span class="font-semibold text-gray-700"><%= cliente.lista %></span>
                  </div>
                <% end %>
                <%= if cliente.direccion && cliente.direccion != "" do %>
                  <div class="col-span-2 flex items-start gap-2 text-gray-500">
                    <svg class="w-3.5 h-3.5 text-indigo-300 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                    <span class="text-gray-400 w-16 flex-shrink-0">Dirección</span>
                    <span class="font-medium text-gray-700 break-words min-w-0"><%= cliente.direccion %></span>
                    <button type="button" data-val={cliente.direccion} onclick="navigator.clipboard.writeText(this.dataset.val)" class="text-gray-300 hover:text-indigo-500 flex-shrink-0"><svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg></button>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Dirección de envío del pedido -->
        <%= if pedido && pedido.direccion_envio && pedido.direccion_envio != "" do %>
          <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div class="px-5 py-3 border-b border-gray-50 flex items-center gap-2">
              <svg class="w-4 h-4 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
              <span class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Dirección de envío</span>
            </div>
            <div class="px-5 py-4">
              <p class="text-sm text-gray-700"><%= pedido.direccion_envio %></p>
            </div>
          </div>
        <% end %>

        <!-- Productos del pedido -->
        <%= if pedido do %>
          <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
            <div class="px-5 py-3 border-b border-gray-50 flex items-center gap-2">
              <svg class="w-4 h-4 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"/></svg>
              <span class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Productos</span>
              <span class="ml-auto text-xs text-gray-400"><%= total_pzas %> pzas · <%= length(pedido.items) %> productos</span>
            </div>
            <div class="divide-y divide-gray-50">
              <%= for item <- pedido.items do %>
                <%
                  img = Map.get(@detalle_imgs, item.producto_codigo)
                  subtotal = item.precio_unitario * item.cantidad
                %>
                <div class="flex items-center gap-4 px-5 py-4">
                  <!-- Imagen -->
                  <div class="w-16 h-16 rounded-xl bg-gray-50 border border-gray-100 flex-shrink-0 overflow-hidden flex items-center justify-center">
                    <%= if img && img != "" do %>
                      <img src={img} class="w-full h-full object-contain" />
                    <% else %>
                      <svg class="w-7 h-7 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                    <% end %>
                  </div>
                  <!-- Info -->
                  <div class="flex-1 min-w-0">
                    <p class="font-semibold text-gray-900 text-sm truncate"><%= item.descripcion || item.producto_codigo %></p>
                    <p class="text-xs text-gray-400 font-mono mt-0.5"><%= item.producto_codigo %></p>
                    <%= if item.precio_unitario > 0 do %>
                      <p class="text-xs text-gray-500 mt-1">
                        $<%= :erlang.float_to_binary(item.precio_unitario / 1, decimals: 2) %> × <%= item.cantidad %>
                      </p>
                    <% end %>
                  </div>
                  <!-- Cantidad + subtotal -->
                  <div class="text-right flex-shrink-0">
                    <span class="inline-flex items-center justify-center w-7 h-7 rounded-lg bg-purple-50 text-xs font-bold text-purple-700"><%= item.cantidad %>×</span>
                    <%= if subtotal > 0 do %>
                      <p class="text-sm font-bold text-gray-900 mt-1">$<%= :erlang.float_to_binary(subtotal / 1, decimals: 2) %></p>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
            <!-- Total -->
            <%= if total_precio > 0 do %>
              <div class="flex items-center justify-between px-5 py-4 bg-gray-50 border-t border-gray-100">
                <span class="text-sm font-semibold text-gray-500">Total del pedido</span>
                <span class="text-xl font-bold text-gray-900">$<%= :erlang.float_to_binary(total_precio / 1, decimals: 2) %></span>
              </div>
            <% end %>
          </div>
        <% end %>

      </div>
    </section>
    """
  end

  defp format_fecha(%DateTime{} = dt, tz) do
    try do
      dt |> DateTime.shift_zone!(tz) |> Calendar.strftime("%d/%m/%Y %H:%M")
    rescue
      _ -> Calendar.strftime(dt, "%d/%m/%Y %H:%M")
    end
  end
  defp format_fecha(%NaiveDateTime{} = ndt, tz) do
    ndt |> DateTime.from_naive!("Etc/UTC") |> format_fecha(tz)
  end
  defp format_fecha(_, _), do: ""
end
