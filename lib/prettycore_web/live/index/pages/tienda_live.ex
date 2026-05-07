defmodule PrettycoreWeb.Tienda do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.ProductosNativos
  alias Prettycore.ListasPrecios
  alias Prettycore.Carritos
  alias Prettycore.Categorias
  alias Prettycore.Carrusel
  alias Prettycore.Secciones
  alias Prettycore.SuperCategorias
  alias Prettycore.Pedidos
  alias Prettycore.Notificaciones
  alias Prettycore.Auth
  alias Prettycore.StockSucursal
  alias Prettycore.Gamas
  alias Prettycore.ClientesNativos

  @impl true
  def mount(_params, _session, socket) do
    role = socket.assigns[:user_role]

    socket =
      socket
      |> assign(:current_page, "tienda")
      |> assign(:sidebar_open, false)
      |> assign(:show_programacion_children, false)
      |> assign(:show_clientes_children, false)
      |> assign(:show_prettycore_children, false)
      |> assign(:productos, [])
      |> assign(:loading, true)
      |> assign(:search, "")
      |> assign(:cart_open, false)
      |> assign(:producto_detalle, nil)
      |> assign(:cart_items, [])
      |> assign(:cart_total_items, 0)
      |> assign(:categorias, [])
      |> assign(:cat_idx, 0)
      |> assign(:cat_nombre, "Todos")
      |> assign(:carrusel, [])
      |> assign(:secciones_tienda, [])
      |> assign(:super_categorias_tienda, [])
      |> assign(:precios, %{})
      |> assign(:precios_nativos, %{})
      |> assign(:stock_map, %{})
      |> assign(:todos_nativos, [])
      |> assign(:ofertas_top10, [])
      |> assign(:ofertas_favoritos, [])
      |> assign(:ofertas_destacados, [])
      |> assign(:pago_modal, false)
      |> assign(:metodo_pago_sel, "contado")
      |> assign(:cliente_nativo_info, nil)
      |> assign(:credito_disponible, Decimal.new(0))
    if connected?(socket) do
      send(self(), :load_productos)
      send(self(), :load_carrusel)
      send(self(), :load_secciones)
      if role not in ["sysadmin", "admin", "oficina"] do
        send(self(), :load_cart)
      end
      if role == "cliente_nativo" do
        send(self(), :load_cliente_info)
      end
    end

    if role == "sysadmin" do
      {:ok, socket, layout: false}
    else
      {:ok, socket}
    end
  end

  # ── Info handlers ──

  @impl true
  def handle_info(:load_carrusel, socket) do
    {:noreply, assign(socket, carrusel: Carrusel.list_activas())}
  end

  @impl true
  def handle_info(:load_secciones, socket) do
    {:noreply, assign(socket, secciones_tienda: Secciones.list_activas())}
  end

  @impl true
  def handle_info(:load_productos, socket) do
    lista        = socket.assigns[:lista_precios]   || 1
    sucursal_num = socket.assigns[:sucursal_numero]
    gamas_cliente = socket.assigns[:gamas] || []
    role          = socket.assigns[:user_role]

    raw_nativos  = ProductosNativos.list_activos()
    todos_nativos = Enum.map(raw_nativos, &ProductosNativos.to_tienda_map/1)

    # Filtrar por gamas asignadas al cliente (solo para clientes_nativo con gamas configuradas)
    todos_nativos =
      if role == "cliente_nativo" and gamas_cliente != [] do
        codigos = Gamas.codigos_set_para_gamas(gamas_cliente)
        Enum.filter(todos_nativos, fn p -> MapSet.member?(codigos, p.codigo) end)
      else
        todos_nativos
      end

    precios_lista = ListasPrecios.get_precios_map(lista)
    stock_map    = if sucursal_num do
      suc_stock = StockSucursal.get_stock_map(sucursal_num)
      # Productos sin entrada en la sucursal = 0 (agotado)
      Map.new(todos_nativos, fn p -> {p.codigo, Map.get(suc_stock, p.codigo, 0)} end)
    else
      raw_nativos
      |> Enum.filter(fn p -> not is_nil(p.stock) end)
      |> Map.new(fn p -> {p.codigo, p.stock} end)
    end
    precios_nativos = Enum.reduce(todos_nativos, %{}, fn p, acc ->
      Map.put(acc, p.codigo, Map.get(precios_lista, p.codigo, p[:precio_base] || 0.0))
    end)
    # Categorías y super categorías derivadas de los productos ya filtrados (sin consulta extra)
    todas_cats = Categorias.list_categorias()
    cats_usadas = todos_nativos |> Enum.map(& &1.categoria) |> MapSet.new()
    categorias =
      Enum.filter(todas_cats, fn cat ->
        String.downcase(cat.nombre) in ["todos", "inicio"] or
        MapSet.member?(cats_usadas, cat.nombre)
      end)

    super_cats_usadas = todos_nativos |> Enum.map(& &1.super_categoria) |> Enum.reject(&is_nil/1) |> MapSet.new()
    super_categorias_tienda =
      SuperCategorias.list_super_categorias()
      |> Enum.filter(fn sc -> MapSet.member?(super_cats_usadas, sc.nombre) end)

    # 4 productos aleatorios por sección de ofertas (del pool ya filtrado por gama)
    ofertas_top10      = Enum.take(Enum.shuffle(todos_nativos), 4)
    ofertas_favoritos  = Enum.take(Enum.shuffle(todos_nativos), 4)
    ofertas_destacados = Enum.take(Enum.shuffle(todos_nativos), 4)

    cat = socket.assigns.cat_nombre
    productos = if cat in [nil, "", "Todos", "INICIO"] do
      todos_nativos
    else
      Enum.filter(todos_nativos, fn p -> p.categoria == cat end)
    end
    {:noreply, assign(socket,
      todos_nativos: todos_nativos,
      productos: productos,
      precios_nativos: precios_nativos,
      stock_map: stock_map,
      categorias: categorias,
      super_categorias_tienda: super_categorias_tienda,
      ofertas_top10: ofertas_top10,
      ofertas_favoritos: ofertas_favoritos,
      ofertas_destacados: ofertas_destacados,
      loading: false
    )}
  end

  @impl true
  def handle_info(:load_cart, socket) do
    %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
  end

  @impl true
  def handle_info(:load_cliente_info, socket) do
    info = ClientesNativos.get(socket.assigns.current_user_id)
    {:noreply, assign(socket, :cliente_nativo_info, info)}
  end


  # ── Event handlers ──

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    productos = search_productos(socket, q)
    {:noreply, assign(socket, search: q, productos: productos)}
  end

  def handle_event("search", %{"value" => q}, socket) do
    productos = search_productos(socket, q)
    {:noreply, assign(socket, search: q, productos: productos)}
  end

  @impl true
  def handle_event("filtrar_categoria", %{"categoria" => cat}, socket) do
    cats = socket.assigns.categorias
    es_todos = String.downcase(cat) in ["inicio", "todos", "all", "inicio", ""]
    nombre_filtro = if es_todos, do: "Todos", else: cat
    idx = Enum.find_index(cats, &(&1.nombre == cat)) || 0
    productos = list_productos_by_categoria(socket, nombre_filtro)
    {:noreply, assign(socket, cat_idx: idx, cat_nombre: nombre_filtro, search: "", productos: productos)}
  end

  @impl true
  def handle_event("cat_next", _, socket) do
    n = max(length(socket.assigns.categorias), 1)
    new_idx = rem(socket.assigns.cat_idx + 1, n)
    apply_categoria(socket, new_idx)
  end

  @impl true
  def handle_event("cat_prev", _, socket) do
    n = max(length(socket.assigns.categorias), 1)
    new_idx = rem(socket.assigns.cat_idx - 1 + n, n)
    apply_categoria(socket, new_idx)
  end

  # ── Carrito ──

  @impl true
  def handle_event("ver_detalle", %{"codigo" => codigo}, socket) do
    prod = Enum.find(socket.assigns.productos, &(&1.codigo == codigo))
    {:noreply, assign(socket, producto_detalle: prod)}
  end

  @impl true
  def handle_event("cerrar_detalle", _, socket) do
    {:noreply, assign(socket, producto_detalle: nil)}
  end

  @impl true
  def handle_event("toggle_cart", _, socket) do
    {:noreply, assign(socket, cart_open: not socket.assigns.cart_open)}
  end

  @impl true
  def handle_event("add_to_cart", _, socket) when socket.assigns.user_role in ["admin", "oficina"] do
    {:noreply, put_flash(socket, :error, "Modo inspección: solo puedes ver la tienda")}
  end

  @impl true
  def handle_event("add_to_cart", %{"codigo" => codigo}, socket) do
    stock_val = Map.get(socket.assigns.stock_map, codigo)
    cart_qty  = case Enum.find(socket.assigns.cart_items, &(&1.producto_codigo == codigo)) do
      nil  -> 0
      item -> item.cantidad
    end

    cond do
      stock_val != nil and stock_val == 0 ->
        {:noreply, put_flash(socket, :error, "Producto agotado")}

      stock_val != nil and cart_qty >= stock_val ->
        {:noreply, put_flash(socket, :error, "Stock máximo alcanzado (#{stock_val} disponibles)")}

      true ->
        case Carritos.add_item(socket.assigns.current_user_id, codigo) do
          {:ok, _} ->
            %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
            producto = Enum.find(socket.assigns.productos, &(&1.codigo == codigo))
            nombre   = (producto && producto.descripcion) || "Producto"
            {:noreply,
             socket
             |> assign(cart_items: items, cart_total_items: total)
             |> put_flash(:info, "✓ #{nombre} agregado al carrito")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al agregar al carrito")}
        end
    end
  end

  @impl true
  def handle_event("remove_from_cart", %{"id" => item_id}, socket) do
    Carritos.remove_item(item_id)
    %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
  end

  @impl true
  def handle_event("update_cantidad", %{"id" => item_id} = params, socket) do
    cantidad_str = Map.get(params, "cantidad") || Map.get(params, "value", "0")
    case Integer.parse(cantidad_str) do
      {cantidad, _} when cantidad > 0 ->
        item      = Enum.find(socket.assigns.cart_items, &(to_string(&1.id) == item_id))
        stock_val = item && Map.get(socket.assigns.stock_map, item.producto_codigo)
        if stock_val != nil and cantidad > stock_val do
          {:noreply, put_flash(socket, :error, "Stock insuficiente (#{stock_val} disponibles)")}
        else
          Carritos.update_cantidad(item_id, cantidad)
          %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
          {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
        end
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("vaciar_carrito", _, socket) do
    Carritos.vaciar_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: [], cart_total_items: 0)}
  end

  @impl true
  def handle_event("hacer_pedido", _, socket) when socket.assigns.user_role in ["admin", "oficina"] do
    {:noreply, put_flash(socket, :error, "Modo inspección: solo puedes ver la tienda")}
  end

  @impl true
  def handle_event("hacer_pedido", _, socket) do
    info = socket.assigns.cliente_nativo_info
    disponible =
      if info && info.tipo_pago == "credito" do
        limite = info.limite_credito || Decimal.new(0)
        usado  = Pedidos.credito_usado(socket.assigns.current_user_id)
        Decimal.sub(limite, Decimal.round(usado, 2))
      else
        Decimal.new(0)
      end
    {:noreply, assign(socket, pago_modal: true, metodo_pago_sel: "contado", credito_disponible: disponible)}
  end

  @impl true
  def handle_event("cerrar_pago_modal", _, socket) do
    {:noreply, assign(socket, pago_modal: false)}
  end

  @impl true
  def handle_event("sel_metodo_pago", %{"metodo" => metodo}, socket) do
    {:noreply, assign(socket, metodo_pago_sel: metodo)}
  end

  @impl true
  def handle_event("confirmar_pedido", _, socket) do
    # Fix 7: carrito no puede estar vacío
    if socket.assigns.cart_items == [] do
      {:noreply, put_flash(socket, :error, "El carrito está vacío")}
    else
      metodo_pago  = socket.assigns.metodo_pago_sel
      sucursal_num = socket.assigns[:sucursal_numero]

      with :ok <- validar_credito(socket, metodo_pago) do
        # Fix 8a: refrescar stock desde BD antes de confirmar
        fresh_stock = if sucursal_num, do: StockSucursal.get_stock_map(sucursal_num), else: socket.assigns.stock_map

        sin_stock = Enum.find(socket.assigns.cart_items, fn item ->
          sv = Map.get(fresh_stock, item.producto_codigo)
          sv != nil and item.cantidad > sv
        end)

        if sin_stock do
          nombre     = (sin_stock.producto && sin_stock.producto.descripcion) || sin_stock.producto_codigo
          disponible = Map.get(fresh_stock, sin_stock.producto_codigo, 0)
          {:noreply, socket |> assign(stock_map: fresh_stock) |> put_flash(:error, "Stock insuficiente para \"#{nombre}\" (disponible: #{disponible})")}
        else
          user    = Auth.get_user(socket.assigns.current_user_id)
          cliente = (user && user.cliente_codigo not in [nil, ""] && user.cliente_codigo) || nil
          dir     = (user && user.dir_codigo     not in [nil, ""] && user.dir_codigo)     || nil
          precios = Map.merge(socket.assigns.precios, socket.assigns.precios_nativos)

          # Fix 8b: decremento de stock dentro de la transacción vía crear_desde_carrito
          case Pedidos.crear_desde_carrito(
                 socket.assigns.current_user_id,
                 socket.assigns.cart_items,
                 precios,
                 cliente,
                 dir,
                 metodo_pago,
                 sucursal_num
               ) do
            {:ok, _pedido} ->
              new_stock_map = if sucursal_num, do: StockSucursal.get_stock_map(sucursal_num), else: fresh_stock
              Carritos.vaciar_carrito(socket.assigns.current_user_id)
              pago_label = if metodo_pago == "credito", do: "a crédito", else: "de contado"
              Notificaciones.crear(socket.assigns.current_user_id, %{
                titulo: "Pedido realizado",
                mensaje: "Tu pedido #{pago_label} fue enviado para procesamiento.",
                tipo: "success"
              })
              {:noreply,
               socket
               |> assign(cart_items: [], cart_total_items: 0, cart_open: false, stock_map: new_stock_map, pago_modal: false)
               |> put_flash(:info, "¡Pedido realizado con éxito!")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Error al realizar el pedido")}
          end
        end
      else
        {:error, msg} ->
          {:noreply, assign(socket, pago_modal: true) |> put_flash(:error, msg)}
      end
    end
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "tienda")
  end

  # ── Render: SysAdmin (sin layout admin, con sidebar sysadmin) ──

  @impl true
  def render(%{user_role: "sysadmin"} = assigns) do
    ~H"""
    <PrettycoreWeb.SysAdminLayout.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <.tienda_page {assigns} />
    </PrettycoreWeb.SysAdminLayout.sidebar>
    """
  end

  # ── Render: Admin / Oficina / Cliente (layout :app wraps con MenuLayout.sidebar) ──

  @impl true
  def render(assigns) do
    ~H"""
    <.tienda_page {assigns} />
    """
  end

  # ── Componente compartido de contenido ──

  defp tienda_page(assigns) do
    ~H"""
    <section class="min-h-screen bg-gray-50" id="tienda-sync-root" phx-hook="TiendaSync">
      <!-- Header sticky -->
      <header class="sticky top-0 z-40 bg-gray-50/95 backdrop-blur-sm border-b border-gray-200 px-3 sm:px-6 py-2 sm:py-3">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0">
            <h1 class="text-base sm:text-2xl font-bold text-gray-900 leading-tight">
              Bienvenido, <%= @current_user_name || "usuario" %> 👋
            </h1>
            <p class="hidden sm:block text-sm text-gray-500 mt-0.5">¡Encuentra todo lo que necesitas al mejor precio!</p>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <%= if not @loading do %>
              <span class="hidden sm:inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-white text-gray-500 border border-gray-200">
                <%= length(@productos) %> productos
              </span>
            <% end %>
            <!-- Botón carrito móvil -->
            <%= if @user_role != "sysadmin" do %>
              <button phx-click="toggle_cart"
                class="lg:hidden relative p-2 rounded-xl bg-white border border-gray-200 text-gray-700 hover:bg-gray-50 transition-colors">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <%= if @cart_total_items > 0 do %>
                  <span class="absolute -top-1 -right-1 w-4 h-4 bg-purple-600 rounded-full text-white text-[9px] font-bold flex items-center justify-center leading-none"><%= @cart_total_items %></span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
        <!-- Search dentro del sticky -->
        <div class="mt-2 relative">
          <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <svg class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </div>
          <input
            type="text"
            phx-keyup="search"
            name="q"
            value={@search}
            placeholder="Buscar productos..."
            class="block w-full pl-9 pr-4 py-2 sm:py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-500 focus:border-transparent shadow-sm transition-all"
          />
        </div>
      </header>

      <!-- Contenido -->
      <div class="px-0 sm:px-2 py-0 sm:py-2">
      <!-- Loading -->
      <%= if @loading do %>
        <div class="flex flex-col items-center justify-center py-24 text-gray-400">
          <svg class="animate-spin h-8 w-8 mb-3 text-purple-500" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          <p class="text-sm">Cargando productos...</p>
        </div>
      <% else %>
        <%
          secs_all = if @secciones_tienda == [],
            do: [%{tipo: "carrusel", nombre: "Carrusel"}, %{tipo: "productos", nombre: "Tienda"}],
            else: @secciones_tienda
          en_inicio = (String.downcase(@cat_nombre || "") in ["todos", "inicio", "all", ""]) and @search == ""
          secs = if en_inicio, do: secs_all, else: Enum.filter(secs_all, &(&1.tipo == "productos"))
        %>
        <div class="flex flex-col md:flex-row gap-0 md:items-start bg-gray-100 min-h-screen">
          <!-- SIDEBAR CATEGORÍAS - solo desktop, lateral -->
          <%= if @categorias != [] do %>
            <div class="hidden md:flex flex-col flex-shrink-0 w-[72px] sticky self-start" style="top: 130px; z-index: 35;">
              <div id="cat-sidebar" phx-hook="ScrollCatActive"
                style="height: calc(100vh - 130px); overflow-y: auto; position: relative; scrollbar-width: none; -ms-overflow-style: none;">
                <%
                  n = length(@categorias)
                %>
                <div data-cat-list data-total={n} style="display:flex;flex-direction:column;align-items:center;">
                  <%= for {cat, loop_idx} <- Enum.with_index(@categorias) do %>
                    <% activa = loop_idx == @cat_idx %>
                    <button
                      phx-click="filtrar_categoria"
                      phx-value-categoria={cat.nombre}
                      data-active={if activa, do: "true", else: "false"}
                      class="flex flex-col items-center w-full focus:outline-none"
                      style="padding:4px;background:transparent;transition:all 0.22s cubic-bezier(0.4,0,0.2,1);"
                    >
                      <%
                        sz = if activa, do: "60px", else: "42px"
                        fs = if activa, do: "18px", else: "13px"
                        sh = if activa, do: "0 4px 12px rgba(0,0,0,0.25)", else: "none"
                        op = if activa, do: "1", else: "0.5"
                      %>
                      <div style={"width:#{sz};height:#{sz};border-radius:50%;overflow:hidden;background:#e5e7eb;border:none;box-shadow:#{sh};transition:all 0.22s cubic-bezier(0.4,0,0.2,1);opacity:#{op};display:flex;align-items:center;justify-content:center;"}>
                        <%= if cat.imagen_url && cat.imagen_url != "" do %>
                          <img src={cat.imagen_url} alt={cat.nombre} style="width:100%;height:100%;object-fit:cover;" />
                        <% else %>
                          <span style={"font-size:#{fs};font-weight:700;color:#9ca3af;line-height:1;user-select:none;"}>
                            <%= (String.first(cat.nombre || "?") || "?") |> String.upcase() %>
                          </span>
                        <% end %>
                      </div>
                      <span style={"font-family:'Outfit',sans-serif;font-size:#{if activa, do: "10px", else: "9px"};font-weight:#{if activa, do: "600", else: "400"};letter-spacing:0.01em;color:#{if activa, do: "#111827", else: "#9ca3af"};margin-top:3px;text-align:center;line-height:1.2;transition:all 0.22s ease-out;display:block;width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"}>
                        <%= cat.nombre %>
                      </span>
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
          <!-- CONTENIDO: todas las secciones -->
          <%
            secs_with_prev =
              secs
              |> Enum.with_index()
              |> Enum.map(fn {sec, i} ->
                prev = if i > 0, do: (Enum.at(secs, i - 1)).tipo, else: nil
                {sec, prev}
              end)
          %>
          <div class="flex-1 min-w-0 w-full overflow-hidden">
          <%= for {sec, prev_tipo} <- secs_with_prev do %>

            <!-- ══ SECCIÓN: CARRUSEL ══ -->
            <%= if sec.tipo == "carrusel" and @carrusel != [] do %>
              <div class="relative w-full">
                <div id="tienda-carrusel" class="flex overflow-x-auto snap-x snap-mandatory scroll-smooth"
                  style="scrollbar-width: none; -ms-overflow-style: none;" phx-hook="Carrusel">
                  <%= for img <- @carrusel do %>
                    <div class="flex-none w-full snap-start relative">
                      <img src={img.url} alt={img.titulo || "Carrusel"} class="w-full h-auto block" />
                      <%= if img.titulo && img.titulo != "" do %>
                        <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/50 to-transparent px-4 py-3" style="z-index:5;">
                          <p class="text-white text-sm font-medium"><%= img.titulo %></p>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <%= if length(@carrusel) > 1 do %>
                  <div class="absolute flex gap-1.5" style="bottom:20px;left:50%;transform:translateX(-50%);z-index:20;">
                    <%= for {_, i} <- Enum.with_index(@carrusel) do %>
                      <div class={"w-1.5 h-1.5 rounded-full bg-white transition-opacity #{if i == 0, do: "opacity-100", else: "opacity-40"}"} id={"carrusel-dot-#{i}"}></div>
                    <% end %>
                  </div>
                  <button id="carrusel-prev" class="absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/30 hover:bg-black/50 rounded-full flex items-center justify-center text-white transition-colors" style="z-index:20;">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/></svg>
                  </button>
                  <button id="carrusel-next" class="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 bg-black/30 hover:bg-black/50 rounded-full flex items-center justify-center text-white transition-colors" style="z-index:20;">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/></svg>
                  </button>
                <% end %>
              </div>
              <!-- CATEGORÍAS MÓVIL: horizontal debajo del carrusel, solo en móvil -->
              <%= if @categorias != [] do %>
                <div class="md:hidden bg-white border-b border-gray-100 overflow-x-auto" style="scrollbar-width:none;-ms-overflow-style:none;">
                  <div class="flex items-end gap-2 px-3 py-2" style="width:max-content;">
                    <%= for {cat, idx} <- Enum.with_index(@categorias) do %>
                      <button
                        phx-click="filtrar_categoria"
                        phx-value-categoria={cat.nombre}
                        class="flex flex-col items-center gap-0.5 focus:outline-none flex-shrink-0"
                        style="transition:all 0.2s ease;"
                      >
                        <%
                          m_sz  = if idx == @cat_idx, do: "50px", else: "38px"
                          m_fs  = if idx == @cat_idx, do: "16px", else: "12px"
                          m_op  = if idx == @cat_idx, do: "1", else: "0.5"
                          m_sh  = if idx == @cat_idx, do: "0 3px 10px rgba(0,0,0,0.2)", else: "none"
                        %>
                        <div style={"width:#{m_sz};height:#{m_sz};border-radius:50%;overflow:hidden;opacity:#{m_op};box-shadow:#{m_sh};transition:all 0.2s ease;background:#e5e7eb;display:flex;align-items:center;justify-content:center;"}>
                          <%= if cat.imagen_url && cat.imagen_url != "" do %>
                            <img src={cat.imagen_url} alt={cat.nombre} style="width:100%;height:100%;object-fit:cover;" />
                          <% else %>
                            <span style={"font-size:#{m_fs};font-weight:700;color:#9ca3af;line-height:1;user-select:none;"}>
                              <%= (String.first(cat.nombre || "?") || "?") |> String.upcase() %>
                            </span>
                          <% end %>
                        </div>
                        <span style={"font-size:9px;font-weight:#{if idx == @cat_idx, do: "700", else: "400"};color:#{if idx == @cat_idx, do: "#111827", else: "#9ca3af"};white-space:nowrap;max-width:56px;overflow:hidden;text-overflow:ellipsis;display:block;text-align:center;"}>
                          <%= cat.nombre %>
                        </span>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>

            <!-- ══ SECCIÓN: TIENDA PRINCIPAL (productos) ══ -->
            <%= if sec.tipo == "productos" do %>
              <div style={"position:relative;z-index:30;background:#ffffff;padding:10px 8px 24px;#{if prev_tipo == "carrusel", do: "margin-top:-16px;border-radius:16px 16px 0 0;", else: "margin-bottom:8px;"}"}>
                    <%= if Enum.empty?(@productos) do %>
                      <div class="text-center py-20 text-gray-400">
                        <p class="text-sm font-medium">Sin productos en esta categoría</p>
                        <button phx-click="filtrar_categoria" phx-value-categoria="Todos"
                          class="mt-3 px-4 py-2 bg-purple-600 text-white text-xs font-semibold rounded-xl hover:bg-purple-500 transition">
                          Ver todos los productos
                        </button>
                      </div>
                    <% else %>
                      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-2 sm:gap-3">
                        <%= for producto <- @productos do %>
                          <% stock_val = Map.get(@stock_map, producto.codigo) %>
                          <% agotado   = stock_val != nil and stock_val == 0 %>
                          <% precio_val = Map.get(@precios, producto.codigo) || Map.get(@precios_nativos, producto.codigo) %>
                          <div class="bg-white rounded-xl overflow-hidden hover:shadow-lg transition-all duration-200 flex flex-col group">
                            <!-- Área clickeable → abre detalle completo -->
                            <button phx-click="ver_detalle" phx-value-codigo={producto.codigo}
                              class="flex flex-col text-left w-full focus:outline-none active:scale-[0.98] transition-transform">
                              <div class="relative w-full aspect-square bg-gray-50 flex items-center justify-center overflow-hidden">
                                <%= if producto.imagen_url && producto.imagen_url != "" do %>
                                  <img src={"#{producto.imagen_url}?t=#{DateTime.to_unix(producto.updated_at)}"} alt={producto.descripcion} class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200" />
                                <% else %>
                                  <svg class="w-10 h-10 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                  </svg>
                                <% end %>
                                <span class={"absolute top-2 left-2 inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold #{if producto.activo, do: "bg-green-500/90 text-white", else: "bg-black/40 text-white"}"}>
                                  <%= if producto.activo, do: "Activo", else: "Inactivo" %>
                                </span>
                              </div>
                              <div class="px-2.5 pt-2.5 flex flex-col flex-1">
                                <h3 class="text-xs font-semibold text-gray-900 leading-tight line-clamp-2 mb-1"><%= producto.descripcion %></h3>
                                <div class="mt-auto pt-2 border-t border-gray-100 space-y-0.5 text-[11px]">
                                  <div class="flex justify-between text-gray-400">
                                    <span>Cód.</span><span class="font-mono font-medium text-gray-600"><%= producto.codigo %></span>
                                  </div>
                                  <div class="flex justify-between text-gray-400">
                                    <span>Mín.</span><span class="font-medium text-gray-600"><%= producto.pzas_min_vta %> pza</span>
                                  </div>
                                  <%= if precio_val do %>
                                    <div class="flex justify-between items-center pt-0.5">
                                      <span class="text-gray-400">Precio</span>
                                      <span class="font-bold text-green-600 text-xs">$<%= :erlang.float_to_binary(precio_val / 1, decimals: 2) %></span>
                                    </div>
                                  <% end %>
                                  <div class="flex justify-between items-center pt-0.5">
                                    <span class="text-gray-400">Stock</span>
                                    <%= cond do %>
                                      <% stock_val == nil -> %>
                                        <span class="font-semibold text-xs text-gray-400">—</span>
                                      <% stock_val == 0 -> %>
                                        <span class="font-semibold text-xs text-red-500">Agotado</span>
                                      <% true -> %>
                                        <span class="font-semibold text-xs text-blue-600"><%= stock_val %> pza<%= if stock_val != 1, do: "s" %></span>
                                    <% end %>
                                  </div>
                                </div>
                              </div>
                            </button>
                            <!-- Botón de acción separado -->
                            <div class="px-2.5 pb-2.5 pt-2">
                              <%= if agotado do %>
                                <span class="w-full flex items-center justify-center gap-1 px-2 py-1.5 bg-red-50 border border-red-200 text-red-500 text-[10px] font-semibold rounded-full">
                                  Agotado
                                </span>
                              <% else %>
                                <%= if @user_role not in ["sysadmin", "admin", "oficina"] do %>
                                  <button phx-click="add_to_cart" phx-value-codigo={producto.codigo}
                                    class="w-full flex items-center justify-center gap-1.5 px-2 py-1.5 bg-gray-900 hover:bg-purple-600 text-white text-[11px] font-medium rounded-full transition-colors">
                                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
                                    Agregar
                                  </button>
                                <% end %>
                                <%= if @user_role in ["admin", "oficina"] do %>
                                  <span class="w-full flex items-center justify-center gap-1 px-2 py-1.5 bg-amber-50 border border-amber-200 text-amber-600 text-[10px] font-medium rounded-full">
                                    Solo inspección
                                  </span>
                                <% end %>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: CARRUSEL DE OFERTAS ══ -->
            <%= if sec.tipo == "ofertas" do %>
              <%
                ofertas_cfg  = sec.config || %{}
                slides_orden =
                  case ofertas_cfg["slides_orden"] do
                    list when is_list(list) and list != [] -> list
                    _ ->
                      ~w(top10 favoritos destacados)
                      |> Enum.map(&%{"kind" => "seccion", "tipo" => &1})
                  end
                slides_count  = length(slides_orden)
                margin_top    = if prev_tipo == "carrusel", do: "margin-top:-16px;", else: ""
                desktop_carousel = slides_count > 3
                track_overflow   = if desktop_carousel, do: "sm:overflow-x-hidden", else: "sm:overflow-x-visible"
                card_desktop     = if desktop_carousel, do: "sm:w-80", else: "sm:flex-1"
                controls_hide    = if desktop_carousel, do: "", else: "sm:hidden"
              %>
              <div style={"padding:8px;#{margin_top}position:relative;z-index:20;"}>
                <div class="relative">
                  <div id="promo-carrusel"
                    phx-hook="PromoCarrusel"
                    class={"flex overflow-x-hidden snap-x snap-mandatory sm:gap-3 #{track_overflow}"}
                    style="scrollbar-width:none;-ms-overflow-style:none;">
                    <%= for {slide, _idx} <- Enum.with_index(slides_orden) do %>
                      <%= if slide["kind"] == "imagen" do %>
                        <div class={"flex-none snap-start w-full #{card_desktop} rounded-2xl overflow-hidden self-start"}
                          style="aspect-ratio:0.87;">
                          <img src={slide["url"]} alt={slide["titulo"] || ""}
                            class="w-full h-full object-cover block" />
                        </div>
                      <% else %>
                        <%
                          s_cfg    = ofertas_cfg[slide["tipo"]] || %{}
                          s_color  = s_cfg["color"] || case slide["tipo"] do
                            "top10" -> "#c0392b"; "favoritos" -> "#1a5276"; "destacados" -> "#1e8449"; _ -> "#6c3483"
                          end
                          s_titulo = s_cfg["titulo"] || case slide["tipo"] do
                            "top10" -> "Top 10"; "favoritos" -> "Favoritos"; "destacados" -> "Destacados"; t -> t
                          end
                          s_prods = case slide["tipo"] do
                            "top10"      -> @ofertas_top10
                            "favoritos"  -> @ofertas_favoritos
                            "destacados" -> @ofertas_destacados
                            _            -> []
                          end
                        %>
                        <%= if s_prods != [] do %>
                          <div class={"flex-none snap-start w-full #{card_desktop} rounded-2xl overflow-hidden p-3 self-start"}
                            style={"background-color:#{s_color};"}>
                            <h3 class="text-white font-black text-lg leading-tight mb-2 px-1"><%= s_titulo %></h3>
                            <div class="grid grid-cols-2 gap-2">
                              <%= for prod <- s_prods do %>
                                <button phx-click="ver_detalle" phx-value-codigo={prod.codigo}
                                  class="relative bg-white rounded-xl overflow-hidden aspect-square flex items-center justify-center group active:scale-95 transition-transform">
                                  <%= if prod.imagen_url && prod.imagen_url != "" do %>
                                    <img src={prod.imagen_url} alt={prod.descripcion}
                                      class="w-full h-full object-contain p-2 group-hover:scale-105 transition-transform duration-200" />
                                  <% else %>
                                    <svg class="w-7 h-7 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                                  <% end %>
                                  <% precio_sec = Map.get(@precios, prod.codigo) || Map.get(@precios_nativos, prod.codigo) %>
                                  <%= if precio_sec && Map.get(@precios, "0") && precio_sec < Map.get(@precios, "0") do %>
                                    <span class="absolute bottom-1 left-1 bg-red-500 text-white text-[8px] font-bold px-1 py-0.5 rounded">
                                      -<%= round((1 - precio_sec / Map.get(@precios, "0")) * 100) %>%
                                    </span>
                                  <% end %>
                                </button>
                              <% end %>
                              <%= for _ <- List.duplicate(nil, max(0, 4 - length(s_prods))) do %>
                                <div class="bg-white/20 rounded-xl aspect-square"></div>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      <% end %>
                    <% end %>
                  </div>
                  <%= if slides_count > 1 do %>
                    <button id="promo-prev"
                      class={"absolute left-1 top-1/2 -translate-y-1/2 z-10 bg-black/30 hover:bg-black/50 text-white rounded-full w-7 h-7 flex items-center justify-center shadow transition #{controls_hide}"}>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
                      </svg>
                    </button>
                    <button id="promo-next"
                      class={"absolute right-1 top-1/2 -translate-y-1/2 z-10 bg-black/30 hover:bg-black/50 text-white rounded-full w-7 h-7 flex items-center justify-center shadow transition #{controls_hide}"}>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7"/>
                      </svg>
                    </button>
                    <div class={"flex justify-center gap-1.5 mt-2 #{controls_hide}"}>
                      <%= for {_, di} <- Enum.with_index(slides_orden) do %>
                        <div id={"promo-dot-#{di}"}
                          class="w-1.5 h-1.5 rounded-full bg-gray-500 transition-opacity"
                          style={"opacity:#{if di == 0, do: "1", else: "0.35"};"}>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: SUPER CATEGORÍAS ══ -->
            <%= if sec.tipo == "supercategorias" and @super_categorias_tienda != [] do %>
              <div style={"padding:12px 12px 8px;#{if prev_tipo == "carrusel", do: "margin-top:-20px;border-radius:16px 16px 0 0;", else: "margin-bottom:8px;"}background:#ffffff;position:relative;z-index:20;"}>
                <p class="text-sm font-bold text-gray-900 mb-3"><%= sec.nombre %></p>
                <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 lg:grid-cols-6 gap-3">
                  <%= for sc <- @super_categorias_tienda do %>
                    <div class="flex flex-col items-center gap-1.5">
                      <div class="w-16 h-16 rounded-2xl overflow-hidden bg-gray-100 shadow-sm border border-gray-100">
                        <%= if sc.imagen_url && sc.imagen_url != "" do %>
                          <img src={sc.imagen_url} alt={sc.nombre} class="w-full h-full object-cover" />
                        <% else %>
                          <div class="w-full h-full flex items-center justify-center bg-purple-50">
                            <span class="text-xl font-black text-purple-300">
                              <%= (String.first(sc.nombre || "?") || "?") |> String.upcase() %>
                            </span>
                          </div>
                        <% end %>
                      </div>
                      <span class="text-[10px] font-medium text-gray-700 text-center leading-tight line-clamp-2 w-full"><%= sc.nombre %></span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: PUBLICIDAD ══ -->
            <%= if sec.tipo == "publicidad" do %>
              <%
                pub_cfg = sec.config || %{}
                pub_c1  = pub_cfg["color1"] || "#9333ea"
                pub_c2  = pub_cfg["color2"] || "#4f46e5"
                pub_bg  = "background:linear-gradient(135deg,#{pub_c1},#{pub_c2});"
              %>
              <div style={if(prev_tipo == "carrusel", do: "margin-top:-20px;border-radius:16px 16px 0 0;overflow:hidden;position:relative;z-index:20;", else: "margin-bottom:8px;position:relative;z-index:20;")}>
                <div class="p-8 text-white relative overflow-hidden" style={pub_bg}>
                  <div class="absolute top-0 right-0 w-64 h-64 rounded-full bg-white/5 -translate-y-1/2 translate-x-1/2"></div>
                  <div class="absolute bottom-0 left-0 w-40 h-40 rounded-full bg-white/5 translate-y-1/2 -translate-x-1/2"></div>
                  <div class="relative">
                    <h2 class="text-2xl font-bold mb-2"><%= pub_cfg["titulo"] || sec.nombre %></h2>
                    <p class="text-white/70 text-sm max-w-md"><%= pub_cfg["subtitulo"] || "Explora nuestro catálogo completo y encuentra los mejores productos para ti." %></p>
                    <button class="mt-5 inline-flex items-center gap-2 px-5 py-2.5 bg-white rounded-xl text-sm font-semibold hover:opacity-90 transition-opacity shadow-sm" style={"color:#{pub_c1};"}>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>
                      <%= pub_cfg["boton"] || "Ver catálogo" %>
                    </button>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: ENVÍOS ══ -->
            <%= if sec.tipo == "envios" do %>
              <div style={"background:#ffffff;padding:16px 16px 20px;#{if prev_tipo == "carrusel", do: "margin-top:-20px;border-radius:16px 16px 0 0;", else: "margin-bottom:8px;"}position:relative;z-index:20;"}>
                <%
                  default_cards = [
                    %{"titulo" => "Envío rápido",  "descripcion" => "Entrega en 24-48h",      "color" => "purple"},
                    %{"titulo" => "Compra segura", "descripcion" => "Protección garantizada", "color" => "green"},
                    %{"titulo" => "Devoluciones",  "descripcion" => "30 días sin preguntas",  "color" => "blue"},
                    %{"titulo" => "Soporte 24/7",  "descripcion" => "Siempre disponible",     "color" => "orange"},
                  ]
                  env_cards =
                    case (sec.config || %{}) do
                      %{"cards" => c} when is_list(c) and length(c) == 4 -> c
                      _ -> default_cards
                    end
                  color_icon = fn color ->
                    case color do
                      "purple" -> {"text-purple-500", "M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0"}
                      "green"  -> {"text-green-500",  "M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"}
                      "blue"   -> {"text-blue-500",   "M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"}
                      _        -> {"text-orange-500", "M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"}
                    end
                  end
                %>
                <p class="text-sm font-bold text-gray-900 mb-3"><%= sec.nombre %></p>
                <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
                  <%= for card <- env_cards do %>
                    <% {icon_class, icon_path} = color_icon.(card["color"] || "purple") %>
                    <div class="flex items-start gap-3 p-3 bg-gray-50 rounded-xl">
                      <svg class={"w-6 h-6 flex-shrink-0 mt-0.5 #{icon_class}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d={icon_path}/>
                      </svg>
                      <div>
                        <p class="text-xs font-semibold text-gray-800 leading-tight"><%= card["titulo"] %></p>
                        <p class="text-[11px] text-gray-400 mt-0.5 leading-tight"><%= card["descripcion"] %></p>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

          <% end %>
          </div><!-- fin flex-1 content -->

          <!-- MINI CARRITO - solo desktop (lg+), en móvil se usa el drawer -->
          <%= if @user_role != "sysadmin" do %>
            <div class="hidden lg:block flex-shrink-0 w-[220px] sticky self-start" style="top: 130px;">
              <div class="bg-white rounded-2xl shadow-sm border border-gray-100 mx-2 overflow-hidden flex flex-col" style="max-height: calc(100vh - 145px);">
                <!-- Header carrito -->
                <div class="flex items-center justify-between px-3 py-2 border-b border-gray-50">
                  <div class="flex items-center gap-1.5">
                    <svg class="w-3.5 h-3.5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                    <span class="text-xs font-semibold text-gray-900">Carrito</span>
                    <%= if @cart_total_items > 0 do %>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded-full text-[10px] font-bold bg-purple-100 text-purple-700"><%= @cart_total_items %></span>
                    <% end %>
                  </div>
                  <%= if @cart_items != [] do %>
                    <button phx-click="vaciar_carrito" data-confirm="¿Vaciar carrito?" class="text-[10px] text-red-400 hover:text-red-600 transition-colors">Vaciar</button>
                  <% end %>
                </div>
                <!-- Items -->
                <div class="flex-1 overflow-y-auto px-2 py-2" style="min-height:80px;">
                  <%= if Enum.empty?(@cart_items) do %>
                    <div class="flex flex-col items-center justify-center py-6 text-gray-300">
                      <svg class="w-8 h-8 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                      <p class="text-[10px]">Vacío</p>
                    </div>
                  <% else %>
                    <div class="space-y-1.5">
                      <%= for item <- @cart_items do %>
                        <div class="flex items-center gap-1.5 bg-gray-50 rounded-lg p-1.5">
                          <div class="w-8 h-8 rounded-md overflow-hidden bg-white border border-gray-100 flex-shrink-0 flex items-center justify-center">
                            <%= if item.producto && item.producto.imagen_url && item.producto.imagen_url != "" do %>
                              <img src={item.producto.imagen_url} class="w-full h-full object-cover" />
                            <% else %>
                              <svg class="w-4 h-4 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                            <% end %>
                          </div>
                          <div class="flex-1 min-w-0">
                            <p class="text-[10px] font-medium text-gray-800 truncate leading-tight"><%= if item.producto, do: item.producto.descripcion, else: item.producto_codigo %></p>
                            <p class="text-[9px] text-gray-400 font-mono leading-tight"><%= item.producto_codigo %></p>
                            <% p_mini = Map.get(@precios, item.producto_codigo) || Map.get(@precios_nativos, item.producto_codigo) || 0.0 %>
                            <%= if p_mini > 0 do %>
                              <p class="text-[10px] font-bold text-green-600 leading-tight">$<%= :erlang.float_to_binary(p_mini / 1, decimals: 2) %></p>
                            <% end %>
                            <div class="flex items-center gap-1 mt-0.5">
                              <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad - 1}
                                class="w-4 h-4 rounded bg-white border border-gray-200 text-gray-500 hover:text-red-500 flex items-center justify-center text-xs font-bold leading-none">−</button>
                              <input
                                type="number"
                                min="1"
                                value={item.cantidad}
                                phx-blur="update_cantidad"
                                phx-value-id={item.id}
                                name="cantidad"
                                class="w-8 h-4 text-[10px] font-semibold text-gray-700 text-center border border-gray-200 rounded bg-white focus:outline-none focus:ring-1 focus:ring-purple-400"
                                onkeydown="if(event.key==='Enter'){this.blur();}"
                              />
                              <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad + 1}
                                class="w-4 h-4 rounded bg-white border border-gray-200 text-gray-500 hover:text-purple-600 flex items-center justify-center text-xs font-bold leading-none">+</button>
                            </div>
                          </div>
                          <button phx-click="remove_from_cart" phx-value-id={item.id}
                            class="w-4 h-4 flex-shrink-0 text-gray-300 hover:text-red-400 transition-colors flex items-center justify-center">
                            <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
                <!-- Footer -->
                <%= if @cart_items != [] do %>
                  <%
                    total_mini = Enum.reduce(@cart_items, 0.0, fn item, acc ->
                      p = Map.get(@precios, item.producto_codigo) || Map.get(@precios_nativos, item.producto_codigo) || Map.get(@precios, "0") || 0.0
                      acc + p * (item.cantidad || 1)
                    end)
                  %>
                  <div class="border-t border-gray-100 px-3 py-2.5 space-y-2">
                    <div class="flex justify-between text-[11px] text-gray-600">
                      <span>Productos</span>
                      <span class="font-semibold text-gray-900"><%= @cart_total_items %> pzas</span>
                    </div>
                    <%= if total_mini > 0 do %>
                      <div class="flex justify-between text-[11px]">
                        <span class="text-gray-400">Importe</span>
                        <span class="font-bold text-green-600">$<%= :erlang.float_to_binary(total_mini / 1, decimals: 2) %></span>
                      </div>
                    <% end %>
                    <%= if @user_role not in ["admin", "oficina"] do %>
                      <button
                        phx-click="hacer_pedido"
                        class="w-full inline-flex items-center justify-center gap-1.5 px-3 py-2 bg-purple-600 hover:bg-purple-500 text-white text-[11px] font-semibold rounded-xl transition-colors"
                      >
                        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                        </svg>
                        Realizar Pedido
                      </button>
                    <% else %>
                      <div class="w-full flex items-center justify-center gap-1.5 px-3 py-2 bg-amber-50 border border-amber-200 text-amber-600 text-[11px] font-semibold rounded-xl">
                        Solo inspección
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

        </div><!-- fin flex gap-0 -->
      <% end %>
      </div><!-- fin contenido -->
    </section>

    <!-- DETALLE PRODUCTO FULL SCREEN -->
    <%= if @producto_detalle do %>
      <%
        pd        = @producto_detalle
        pd_precio = Map.get(@precios, pd.codigo) || Map.get(@precios_nativos, pd.codigo)
        pd_raw    = pd.raw || %{}
        pd_desc_larga = pd_raw["descripcionLarga"] || pd_raw["desc_larga"] || pd_raw["description"] || ""
        pd_unidad     = pd_raw["unidadMedida"] || pd_raw["unidad"] || ""
        pd_peso       = pd_raw["peso"] || ""
        pd_volumen    = pd_raw["volumen"] || ""
        pd_categoria  = pd.categoria || pd_raw["categoria"] || pd_raw["linea"] || ""
        pd_stock      = Map.get(@stock_map, pd.codigo)
        pd_agotado    = pd_stock != nil and pd_stock == 0
      %>
      <div class="fixed inset-0 z-[70] bg-white overflow-y-auto" style="overscroll-behavior:contain;">

        <!-- Barra superior: volver -->
        <div class="sticky top-0 z-10 bg-white/95 backdrop-blur-sm border-b border-gray-100 px-4 py-3 flex items-center gap-3">
          <button phx-click="cerrar_detalle"
            class="flex items-center gap-1.5 text-sm font-medium text-gray-500 hover:text-gray-900 transition-colors">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <span class="text-gray-300">|</span>
          <p class="text-xs text-gray-400 truncate"><%= pd_categoria %><%= if pd_categoria != "", do: " › " %><%= pd.descripcion %></p>
        </div>

        <!-- Contenido principal: imagen + info -->
        <div class="max-w-5xl mx-auto px-4 py-6 md:py-10">
          <div class="flex flex-col md:flex-row gap-8 md:gap-12">

            <!-- Columna imagen -->
            <div class="md:w-2/5 flex-shrink-0">
              <div class="relative bg-gray-50 rounded-2xl overflow-hidden aspect-square flex items-center justify-center border border-gray-100">
                <%= if pd.imagen_url && pd.imagen_url != "" do %>
                  <img src={"#{pd.imagen_url}?t=#{DateTime.to_unix(pd.updated_at)}"} alt={pd.descripcion}
                    class="w-full h-full object-contain p-6" />
                <% else %>
                  <svg class="w-24 h-24 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                  </svg>
                <% end %>
                <!-- Badge disponible/agotado -->
                <%
                  badge_color = if pd_agotado, do: "bg-red-500 text-white", else: if(pd.activo, do: "bg-green-500 text-white", else: "bg-gray-400 text-white")
                  badge_label = if pd_agotado, do: "Agotado", else: if(pd.activo, do: "Disponible", else: "No disponible")
                %>
                <span class={"absolute top-3 left-3 text-[10px] font-bold px-2.5 py-1 rounded-full #{badge_color}"}>
                  <%= badge_label %>
                </span>
              </div>
            </div>

            <!-- Columna info -->
            <div class="md:w-3/5 flex flex-col gap-5">

              <!-- Nombre + marca -->
              <div>
                <%= if pd.marca && pd.marca != "" do %>
                  <p class="text-xs font-semibold text-purple-600 uppercase tracking-widest mb-1"><%= pd.marca %></p>
                <% end %>
                <h1 class="text-2xl md:text-3xl font-bold text-gray-900 leading-tight"><%= pd.descripcion %></h1>
                <%= if pd.desc_corta && pd.desc_corta != "" do %>
                  <p class="text-sm text-gray-500 mt-1"><%= pd.desc_corta %></p>
                <% end %>
              </div>

              <!-- Precio -->
              <div class="py-4 border-t border-b border-gray-100">
                <%= if pd_precio do %>
                  <p class="text-4xl font-black text-green-600">$<%= :erlang.float_to_binary(pd_precio / 1, decimals: 2) %></p>
                  <%= if pd.iva && pd.iva > 0 do %>
                    <p class="text-xs text-gray-400 mt-0.5">+ IVA <%= pd.iva %>%</p>
                  <% end %>
                <% else %>
                  <p class="text-sm text-gray-400 italic">Precio no disponible</p>
                <% end %>
              </div>

              <!-- Especificaciones -->
              <div class="space-y-2">
                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Especificaciones</h3>
                <table class="w-full text-sm">
                  <tbody class="divide-y divide-gray-50">
                    <tr class="flex justify-between py-2">
                      <td class="text-gray-500">Código</td>
                      <td class="font-mono font-semibold text-gray-800"><%= pd.codigo %></td>
                    </tr>
                    <tr class="flex justify-between py-2">
                      <td class="text-gray-500">Mínimo de compra</td>
                      <td class="font-semibold text-gray-800"><%= pd.pzas_min_vta %> pza<%= if pd.pzas_min_vta != 1, do: "s" %></td>
                    </tr>
                    <%
                      stock_color = if pd_agotado, do: "text-red-500", else: if(pd_stock == nil, do: "text-gray-400", else: "text-blue-600")
                      stock_label = if pd_agotado, do: "Agotado", else: if(pd_stock == nil, do: "—", else: "#{pd_stock} pza#{if pd_stock != 1, do: "s"}")
                    %>
                    <tr class="flex justify-between py-2">
                      <td class="text-gray-500">Stock</td>
                      <td class={"font-semibold #{stock_color}"}><%= stock_label %></td>
                    </tr>
                    <%= if pd_unidad != "" do %>
                      <tr class="flex justify-between py-2">
                        <td class="text-gray-500">Unidad</td>
                        <td class="font-semibold text-gray-800"><%= pd_unidad %></td>
                      </tr>
                    <% end %>
                    <%= if pd_peso != "" do %>
                      <tr class="flex justify-between py-2">
                        <td class="text-gray-500">Peso</td>
                        <td class="font-semibold text-gray-800"><%= pd_peso %></td>
                      </tr>
                    <% end %>
                    <%= if pd_volumen != "" do %>
                      <tr class="flex justify-between py-2">
                        <td class="text-gray-500">Volumen</td>
                        <td class="font-semibold text-gray-800"><%= pd_volumen %></td>
                      </tr>
                    <% end %>
                    <%= if pd_categoria != "" do %>
                      <tr class="flex justify-between py-2">
                        <td class="text-gray-500">Categoría</td>
                        <td class="font-semibold text-gray-800"><%= pd_categoria %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <!-- Descripción larga -->
              <%= if pd_desc_larga != "" do %>
                <div class="pt-2 border-t border-gray-100">
                  <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-2">Descripción</h3>
                  <p class="text-sm text-gray-600 leading-relaxed"><%= pd_desc_larga %></p>
                </div>
              <% end %>

              <!-- Botón agregar -->
              <div class="pt-2 mt-auto">
                <%= if @user_role not in ["sysadmin", "admin", "oficina"] do %>
                  <%= if pd_agotado do %>
                    <div class="w-full flex items-center justify-center gap-2 py-4 bg-red-50 border border-red-200 text-red-500 font-semibold rounded-2xl text-sm">
                      Agotado
                    </div>
                  <% else %>
                    <button phx-click="add_to_cart" phx-value-codigo={pd.codigo}
                      class="w-full flex items-center justify-center gap-2 py-4 bg-gray-900 hover:bg-purple-600 text-white font-semibold rounded-2xl transition-colors text-sm shadow-lg">
                      <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"/>
                      </svg>
                      Agregar al carrito
                    </button>
                  <% end %>
                <% end %>
                <%= if @user_role in ["admin", "oficina"] do %>
                  <div class="w-full flex items-center justify-center gap-2 py-4 bg-amber-50 border border-amber-200 text-amber-600 font-medium rounded-2xl text-sm">
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                    </svg>
                    Modo inspección
                  </div>
                <% end %>
              </div>

            </div>
          </div>
        </div>
      </div>
    <% end %>

    <!-- DRAWER CARRITO MÓVIL (lg: oculto, lo maneja el sidebar) -->
    <%= if @user_role not in ["sysadmin", "admin", "oficina"] and @cart_open do %>
      <div class="fixed inset-0 z-[60] flex items-end lg:hidden">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" phx-click="toggle_cart"></div>
        <!-- Drawer -->
        <div class="relative w-full bg-white rounded-t-2xl shadow-2xl flex flex-col" style="max-height:82vh;">
          <!-- Handle -->
          <div class="flex justify-center pt-2.5 pb-1">
            <div class="w-10 h-1 bg-gray-200 rounded-full"></div>
          </div>
          <!-- Header -->
          <div class="flex items-center justify-between px-4 py-3 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <span class="font-bold text-gray-900 text-sm">Carrito</span>
              <%= if @cart_total_items > 0 do %>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-purple-100 text-purple-700"><%= @cart_total_items %></span>
              <% end %>
            </div>
            <div class="flex items-center gap-3">
              <%= if @cart_items != [] do %>
                <button phx-click="vaciar_carrito" data-confirm="¿Vaciar carrito?" class="text-xs text-red-400 hover:text-red-600 transition-colors">Vaciar</button>
              <% end %>
              <button phx-click="toggle_cart" class="p-1.5 rounded-lg hover:bg-gray-100 text-gray-500 transition-colors">
                <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
              </button>
            </div>
          </div>
          <!-- Items -->
          <div class="flex-1 overflow-y-auto px-4 py-3" style="overscroll-behavior:contain;">
            <%= if Enum.empty?(@cart_items) do %>
              <div class="flex flex-col items-center justify-center py-12 text-gray-300">
                <svg class="w-14 h-14 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <p class="text-sm font-medium text-gray-400">Tu carrito está vacío</p>
                <p class="text-xs text-gray-300 mt-1">Agrega productos para comenzar</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for item <- @cart_items do %>
                  <div class="flex items-center gap-3 bg-gray-50 rounded-xl p-3">
                    <div class="w-12 h-12 rounded-lg overflow-hidden bg-white border border-gray-100 flex-shrink-0 flex items-center justify-center">
                      <%= if item.producto && item.producto.imagen_url && item.producto.imagen_url != "" do %>
                        <img src={item.producto.imagen_url} class="w-full h-full object-cover" />
                      <% else %>
                        <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>
                      <% end %>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-sm font-medium text-gray-800 truncate leading-tight"><%= if item.producto, do: item.producto.descripcion, else: item.producto_codigo %></p>
                      <p class="text-xs text-gray-400 font-mono leading-tight"><%= item.producto_codigo %></p>
                      <% p_drawer = Map.get(@precios, item.producto_codigo) || Map.get(@precios_nativos, item.producto_codigo) || Map.get(@precios, "0") %>
                      <%= if p_drawer do %>
                        <p class="text-xs text-green-600 font-bold mt-0.5">$<%= :erlang.float_to_binary(p_drawer / 1, decimals: 2) %></p>
                      <% end %>
                    </div>
                    <div class="flex items-center gap-1.5 flex-shrink-0">
                      <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad - 1}
                        class="w-7 h-7 rounded-lg bg-white border border-gray-200 text-gray-500 hover:text-red-500 flex items-center justify-center text-sm font-bold shadow-sm">−</button>
                      <input
                        type="number"
                        min="1"
                        value={item.cantidad}
                        phx-blur="update_cantidad"
                        phx-value-id={item.id}
                        name="cantidad"
                        class="w-12 h-7 text-sm font-semibold text-gray-700 text-center border border-gray-200 rounded-lg bg-white focus:outline-none focus:ring-1 focus:ring-purple-400"
                        onkeydown="if(event.key==='Enter'){this.blur();}"
                      />
                      <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad + 1}
                        class="w-7 h-7 rounded-lg bg-white border border-gray-200 text-gray-500 hover:text-purple-600 flex items-center justify-center text-sm font-bold shadow-sm">+</button>
                      <button phx-click="remove_from_cart" phx-value-id={item.id}
                        class="w-7 h-7 ml-1 flex-shrink-0 text-gray-300 hover:text-red-400 transition-colors flex items-center justify-center rounded-lg hover:bg-red-50">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <!-- Footer con total y botón pedido -->
          <%= if @cart_items != [] do %>
            <%
              total_drawer = Enum.reduce(@cart_items, 0.0, fn item, acc ->
                p = Map.get(@precios, item.producto_codigo) || Map.get(@precios_nativos, item.producto_codigo) || Map.get(@precios, "0") || 0.0
                acc + p * (item.cantidad || 1)
              end)
            %>
            <div class="border-t border-gray-100 px-4 pt-3 pb-6 space-y-3">
              <div class="flex justify-between items-center">
                <span class="text-sm text-gray-500"><%= @cart_total_items %> productos</span>
                <%= if total_drawer > 0 do %>
                  <span class="text-base font-bold text-green-600">$<%= :erlang.float_to_binary(total_drawer / 1, decimals: 2) %></span>
                <% end %>
              </div>
              <%= if @user_role not in ["admin", "oficina"] do %>
                <button
                  phx-click="hacer_pedido"
                  data-confirm="¿Confirmar pedido?"
                  class="w-full inline-flex items-center justify-center gap-2 px-4 py-3 bg-purple-600 hover:bg-purple-500 text-white text-sm font-semibold rounded-xl transition-colors shadow-md"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
                  </svg>
                  Realizar Pedido
                </button>
              <% else %>
                <div class="w-full flex items-center justify-center gap-2 px-4 py-3 bg-amber-50 border border-amber-200 text-amber-600 text-sm font-semibold rounded-xl">
                  Solo inspección
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <!-- ═══ MODAL TIPO DE PAGO ═══ -->
    <%= if @pago_modal do %>
      <%
        info          = @cliente_nativo_info
        tiene_credito = info != nil and info.tipo_pago == "credito"
        total_pedido  = Enum.reduce(@cart_items, 0.0, fn item, acc ->
          p = Map.get(@precios, item.producto_codigo) || Map.get(@precios_nativos, item.producto_codigo) || 0.0
          acc + p * (item.cantidad || 1)
        end)
        disponible_dec = @credito_disponible
        alcanza        = tiene_credito and Decimal.compare(Decimal.round(Decimal.from_float(total_pedido), 2), Decimal.round(disponible_dec, 2)) in [:lt, :eq]
        puede_confirmar = @metodo_pago_sel == "contado" or (tiene_credito and alcanza)
      %>
      <div class="fixed inset-0 z-[80] flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm">
        <div class="w-full max-w-sm bg-white rounded-2xl shadow-2xl overflow-hidden">
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div>
              <h2 class="text-base font-bold text-gray-900">Tipo de pago</h2>
              <p class="text-xs text-gray-400 mt-0.5">Selecciona cómo deseas pagar</p>
            </div>
            <button phx-click="cerrar_pago_modal" class="p-1.5 rounded-lg hover:bg-gray-100 text-gray-400 transition-colors">
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/></svg>
            </button>
          </div>

          <div class="px-5 py-4 space-y-4">
            <div class="grid grid-cols-2 gap-3">
              <!-- Contado -->
              <button phx-click="sel_metodo_pago" phx-value-metodo="contado"
                class={"p-4 rounded-xl border-2 text-left transition-all #{if @metodo_pago_sel == "contado", do: "border-amber-400 bg-amber-50", else: "border-gray-200 hover:border-gray-300 bg-white"}"}>
                <div class={"w-9 h-9 rounded-full flex items-center justify-center mb-2.5 #{if @metodo_pago_sel == "contado", do: "bg-amber-400", else: "bg-gray-100"}"}>
                  <svg class={"w-4 h-4 #{if @metodo_pago_sel == "contado", do: "text-white", else: "text-gray-500"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z"/>
                  </svg>
                </div>
                <p class="text-sm font-bold text-gray-800">Contado</p>
                <p class="text-xs text-gray-400 mt-0.5">Pago inmediato</p>
              </button>

              <!-- Crédito -->
              <button phx-click={if tiene_credito, do: "sel_metodo_pago", else: nil}
                phx-value-metodo="credito"
                class={"p-4 rounded-xl border-2 text-left transition-all #{cond do
                  not tiene_credito -> "border-gray-100 bg-gray-50 opacity-50 cursor-not-allowed"
                  @metodo_pago_sel == "credito" -> "border-blue-400 bg-blue-50"
                  true -> "border-gray-200 hover:border-gray-300 bg-white"
                end}"}>
                <div class={"w-9 h-9 rounded-full flex items-center justify-center mb-2.5 #{if @metodo_pago_sel == "credito", do: "bg-blue-500", else: "bg-gray-100"}"}>
                  <svg class={"w-4 h-4 #{if @metodo_pago_sel == "credito", do: "text-white", else: "text-gray-500"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/>
                  </svg>
                </div>
                <p class="text-sm font-bold text-gray-800">Crédito</p>
                <p class="text-xs text-gray-400 mt-0.5">
                  <%= if tiene_credito, do: "#{info.dias_credito || 0} días", else: "No disponible" %>
                </p>
              </button>
            </div>

            <!-- Detalle de crédito -->
            <%= if @metodo_pago_sel == "credito" and tiene_credito do %>
              <div class={"rounded-xl p-3 border #{if alcanza, do: "bg-green-50 border-green-200", else: "bg-red-50 border-red-200"}"}>
                <div class="flex items-center gap-2 mb-2">
                  <%= if alcanza do %>
                    <svg class="w-4 h-4 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                    <p class="text-xs font-semibold text-green-700">Crédito disponible</p>
                  <% else %>
                    <svg class="w-4 h-4 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/></svg>
                    <p class="text-xs font-semibold text-red-700">Crédito insuficiente</p>
                  <% end %>
                </div>
                <div class="grid grid-cols-3 gap-2 text-xs">
                  <div>
                    <p class="text-gray-400">Disponible</p>
                    <p class={"font-bold #{if Decimal.compare(disponible_dec, Decimal.new(0)) == :gt, do: "text-gray-700", else: "text-red-600"}"}>$<%= format_miles(disponible_dec) %></p>
                  </div>
                  <div>
                    <p class="text-gray-400">Este pedido</p>
                    <p class={"font-bold #{if alcanza, do: "text-green-700", else: "text-red-600"}"}> $<%= :erlang.float_to_binary(total_pedido / 1, decimals: 2) %></p>
                  </div>
                  <div>
                    <p class="text-gray-400">Plazo</p>
                    <p class="font-bold text-gray-700"><%= info.dias_credito || 0 %> días</p>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- Total y confirmar -->
            <div class="bg-gray-50 rounded-xl px-4 py-3 flex justify-between items-center">
              <span class="text-sm text-gray-500">Total</span>
              <span class="text-lg font-bold text-gray-900">$<%= :erlang.float_to_binary(total_pedido / 1, decimals: 2) %></span>
            </div>

            <button phx-click="confirmar_pedido"
              disabled={not puede_confirmar}
              class={"w-full py-3 rounded-xl text-sm font-bold transition-colors #{if puede_confirmar, do: "bg-purple-600 hover:bg-purple-500 text-white", else: "bg-gray-200 text-gray-400 cursor-not-allowed"}"}>
              <%= if @metodo_pago_sel == "credito" and tiene_credito and not alcanza do %>
                Crédito insuficiente
              <% else %>
                Confirmar pedido
              <% end %>
            </button>
          </div>
        </div>
      </div>
    <% end %>

    """
  end

  defp validar_credito(socket, "credito") do
    info = socket.assigns.cliente_nativo_info
    cond do
      is_nil(info) ->
        {:error, "Este cliente no tiene crédito configurado"}
      info.tipo_pago != "credito" ->
        {:error, "Este cliente no tiene crédito habilitado"}
      true ->
        total      = calc_cart_total(socket.assigns.cart_items, socket.assigns.precios, socket.assigns.precios_nativos)
        limite     = info.limite_credito || Decimal.new(0)
        usado      = Pedidos.credito_usado(socket.assigns.current_user_id)
        disponible = Decimal.sub(limite, Decimal.round(usado, 2))
        if Decimal.compare(Decimal.round(Decimal.from_float(total), 2), Decimal.round(disponible, 2)) in [:lt, :eq] do
          :ok
        else
          {:error, "El total ($#{:erlang.float_to_binary(total / 1, decimals: 2)}) supera tu crédito disponible ($#{format_miles(disponible)})"}
        end
    end
  end
  defp validar_credito(_socket, _metodo), do: :ok

  defp calc_cart_total(cart_items, precios, precios_nativos) do
    Enum.reduce(cart_items, 0.0, fn item, acc ->
      p = Map.get(precios, item.producto_codigo) || Map.get(precios_nativos, item.producto_codigo) || 0.0
      acc + p * (item.cantidad || 1)
    end)
  end

  defp format_miles(decimal) do
    str = Decimal.to_string(decimal)
    [int_part | rest] = String.split(str, ".")
    formatted = int_part
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.join/1)
      |> Enum.join(",")
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.join()
    case rest do
      [] -> formatted
      [dec] -> "#{formatted}.#{dec}"
    end
  end

  defp apply_categoria(socket, idx) do
    cat = Enum.at(socket.assigns.categorias, idx)
    cat_nombre = if cat, do: cat.nombre, else: "Todos"
    productos = list_productos_by_categoria(socket, cat_nombre)
    {:noreply, assign(socket, cat_idx: idx, cat_nombre: cat_nombre, search: "", productos: productos)}
  end

  defp list_productos_by_categoria(socket, cat_nombre) do
    all = socket.assigns[:todos_nativos] || (ProductosNativos.list_activos() |> Enum.map(&ProductosNativos.to_tienda_map/1))
    es_todos = cat_nombre in [nil, ""] or String.downcase(cat_nombre) in ["todos", "inicio", "all"]
    if es_todos, do: all, else: Enum.filter(all, fn p -> p.categoria == cat_nombre end)
  end

  defp search_productos(socket, q) do
    all = socket.assigns[:todos_nativos] || (ProductosNativos.list_activos() |> Enum.map(&ProductosNativos.to_tienda_map/1))
    q_down = String.downcase(q)
    Enum.filter(all, fn p ->
      String.contains?(String.downcase(p.descripcion || ""), q_down) or
      String.contains?(String.downcase(p.codigo || ""), q_down)
    end)
  end
end
