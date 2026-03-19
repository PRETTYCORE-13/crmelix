defmodule PrettycoreWeb.Tienda do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Productos
  alias Prettycore.Sftp
  alias Prettycore.Carritos
  alias Prettycore.Categorias
  alias Prettycore.Carrusel
  alias Prettycore.Secciones

  @max_file_size 10_000_000  # 10 MB

  def mount(_params, _session, socket) do
    role = socket.assigns[:user_role]

    socket =
      socket
      |> assign(:current_page, "tienda")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
      |> assign(:productos, [])
      |> assign(:loading, true)
      |> assign(:syncing, false)
      |> assign(:search, "")
      |> assign(:editing_imagen_codigo, nil)
      |> assign(:upload_error, nil)
      |> assign(:uploading_imagen, false)
      |> assign(:cart_open, false)
      |> assign(:cart_items, [])
      |> assign(:cart_total_items, 0)
      |> assign(:categorias, [])
      |> assign(:cat_idx, 0)
      |> assign(:cat_nombre, "Todos")
      |> assign(:carrusel, [])
      |> assign(:secciones_tienda, [])
      |> allow_upload(:imagen,
          accept: ~w(.jpg .jpeg .png .webp .gif),
          max_entries: 1,
          max_file_size: @max_file_size)

    if connected?(socket) do
      send(self(), :load_productos)
      send(self(), :load_categorias)
      send(self(), :load_carrusel)
      send(self(), :load_secciones)
      if role != "sysadmin", do: send(self(), :load_cart)
    end

    if role == "sysadmin" do
      {:ok, socket, layout: false}
    else
      {:ok, socket}
    end
  end

  # ── Info handlers ──

  @impl true
  def handle_info(:load_categorias, socket) do
    cats = Categorias.list_categorias()
    {:noreply, assign(socket, categorias: cats)}
  end

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
    productos = Productos.list_productos()
    {:noreply, assign(socket, productos: productos, loading: false)}
  end

  @impl true
  def handle_info(:load_cart, socket) do
    %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
  end

  @impl true
  def handle_info(:do_sync, socket) do
    case Productos.sync_from_api() do
      {:ok, count} ->
        productos = Productos.list_productos()
        {:noreply,
         socket
         |> assign(syncing: false, productos: productos, search: "", cat_idx: 0, cat_nombre: "Todos")
         |> put_flash(:info, "#{count} productos sincronizados")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(syncing: false)
         |> put_flash(:error, "Error al sincronizar productos")}
    end
  end

  # ── Event handlers ──

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    productos = Productos.search_by_categoria(q, socket.assigns.cat_nombre)
    {:noreply, assign(socket, search: q, productos: productos)}
  end

  @impl true
  def handle_event("filtrar_categoria", %{"categoria" => cat}, socket) do
    cats = socket.assigns.categorias
    idx = Enum.find_index(cats, &(&1.nombre == cat)) || 0
    productos = Productos.list_by_categoria(cat)
    {:noreply, assign(socket, cat_idx: idx, cat_nombre: cat, search: "", productos: productos)}
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

  defp apply_categoria(socket, idx) do
    cat = Enum.at(socket.assigns.categorias, idx)
    cat_nombre = if cat, do: cat.nombre, else: "Todos"
    productos = Productos.list_by_categoria(cat_nombre)
    {:noreply, assign(socket, cat_idx: idx, cat_nombre: cat_nombre, search: "", productos: productos)}
  end

  @impl true
  def handle_event("sync", _, socket) do
    send(self(), :do_sync)
    {:noreply, assign(socket, syncing: true)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_imagen", %{"codigo" => codigo}, socket) do
    {:noreply, assign(socket, editing_imagen_codigo: codigo, upload_error: nil)}
  end

  @impl true
  def handle_event("cancel_imagen", _, socket) do
    socket =
      socket.assigns.uploads.imagen.entries
      |> Enum.reduce(socket, fn entry, acc ->
        cancel_upload(acc, :imagen, entry.ref)
      end)
    {:noreply, assign(socket, editing_imagen_codigo: nil, upload_error: nil)}
  end

  @impl true
  def handle_event("subir_imagen", %{"codigo" => codigo}, socket) do
    entries = socket.assigns.uploads.imagen.entries

    if entries == [] do
      {:noreply, assign(socket, upload_error: "Selecciona una imagen primero")}
    else
      socket = assign(socket, uploading_imagen: true, upload_error: nil)

      results =
        consume_uploaded_entries(socket, :imagen, fn %{path: path}, entry ->
          content = File.read!(path)
          ext = entry.client_name |> Path.extname() |> String.downcase()
          case Sftp.upload_product_image(codigo, ext, content) do
            {:ok, url}       -> {:ok, {:ok, url}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case results do
        [{:ok, url}] ->
          case Productos.update_imagen(codigo, url) do
            {:ok, _} ->
              productos =
                if socket.assigns.search == "",
                  do: Productos.list_productos(),
                  else: Productos.search_productos(socket.assigns.search)

              {:noreply,
               socket
               |> assign(
                 editing_imagen_codigo: nil,
                 upload_error: nil,
                 uploading_imagen: false,
                 productos: productos
               )
               |> put_flash(:info, "Imagen actualizada correctamente")}

            {:error, _} ->
              {:noreply,
               assign(socket,
                 upload_error: "Imagen subida al servidor pero error al guardar en BD",
                 uploading_imagen: false
               )}
          end

        [{:error, reason}] ->
          {:noreply, assign(socket, upload_error: "Error SFTP: #{reason}", uploading_imagen: false)}

        _ ->
          {:noreply, assign(socket, upload_error: "Error inesperado", uploading_imagen: false)}
      end
    end
  end

  # ── Carrito ──

  @impl true
  def handle_event("toggle_cart", _, socket) do
    {:noreply, assign(socket, cart_open: not socket.assigns.cart_open)}
  end

  @impl true
  def handle_event("add_to_cart", %{"codigo" => codigo}, socket) do
    case Carritos.add_item(socket.assigns.current_user_id, codigo) do
      {:ok, _} ->
        %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
        {:noreply,
         socket
         |> assign(cart_items: items, cart_total_items: total, cart_open: true)
         |> put_flash(:info, "Producto agregado al carrito")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al agregar al carrito")}
    end
  end

  @impl true
  def handle_event("remove_from_cart", %{"id" => item_id}, socket) do
    Carritos.remove_item(item_id)
    %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
  end

  @impl true
  def handle_event("update_cantidad", %{"id" => item_id, "cantidad" => cantidad_str}, socket) do
    cantidad = String.to_integer(cantidad_str)
    Carritos.update_cantidad(item_id, cantidad)
    %{items: items, total_items: total} = Carritos.get_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: items, cart_total_items: total)}
  end

  @impl true
  def handle_event("vaciar_carrito", _, socket) do
    Carritos.vaciar_carrito(socket.assigns.current_user_id)
    {:noreply, assign(socket, cart_items: [], cart_total_items: 0)}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar" -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"         -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"       -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "tienda"         -> {:noreply, socket}
      "categorias"       -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias" -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"         -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"         -> {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}
      "usuarios"          -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "seccion_top10"     -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos" -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"-> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"-> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"    -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                   -> {:noreply, socket}
    end
  end

  # ── Helpers ──

  defp can_edit_images?(role, permissions) do
    role in ["admin", "sysadmin"] or "editar_imagenes" in (permissions || [])
  end

  defp upload_error_to_string(:too_large),      do: "Archivo muy grande (máx 10 MB)"
  defp upload_error_to_string(:not_accepted),   do: "Tipo no permitido (jpg, png, webp, gif)"
  defp upload_error_to_string(:too_many_files), do: "Solo se permite 1 imagen"
  defp upload_error_to_string(_),               do: "Error al cargar archivo"

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
    <section class="min-h-screen bg-gray-50">
      <!-- Header sticky -->
      <header class="sticky top-0 z-40 bg-gray-50/95 backdrop-blur-sm border-b border-gray-200 px-4 sm:px-6 py-3">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Tienda</h1>
            <p class="text-sm text-gray-500 mt-0.5">Catálogo de productos</p>
          </div>
          <div class="flex items-center gap-2 flex-shrink-0">
            <%= if not @loading do %>
              <span class="hidden sm:inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-white text-gray-500 border border-gray-200">
                <%= length(@productos) %> productos
              </span>
            <% end %>
            <button
              phx-click="sync"
              disabled={@syncing}
              class={"inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all #{if @syncing, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-blue-500 text-white hover:bg-blue-400"}"}
            >
              <svg class={"w-4 h-4 #{if @syncing, do: "animate-spin"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <%= if @syncing, do: "Sincronizando...", else: "Sincronizar" %>
            </button>
            <!-- Carrito: solo roles no-sysadmin -->
            <%= if @user_role != "sysadmin" do %>
              <button
                phx-click="toggle_cart"
                class="relative inline-flex items-center justify-center w-10 h-10 rounded-xl bg-white border border-gray-200 text-gray-600 hover:text-gray-900 hover:border-gray-900 transition-all shadow-sm"
                title="Ver carrito"
              >
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <%= if @cart_total_items > 0 do %>
                  <span class="absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] px-1 bg-blue-500 text-white text-[10px] font-bold rounded-full flex items-center justify-center">
                    <%= @cart_total_items %>
                  </span>
                <% end %>
              </button>
            <% end %>
          </div>
        </div>
        <!-- Search dentro del sticky -->
        <div class="mt-2.5 relative">
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
            placeholder="Buscar por nombre, código o marca..."
            class="block w-full pl-9 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-500 focus:border-transparent shadow-sm transition-all"
          />
        </div>
      </header>

      <!-- Contenido -->
      <div class="px-4 sm:px-6 py-4">
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
          secs = if @secciones_tienda == [],
            do: [%{tipo: "carrusel", nombre: "Carrusel"}, %{tipo: "productos", nombre: "Tienda"}],
            else: @secciones_tienda
          puede_editar = can_edit_images?(@user_role, @user_permissions)
        %>
        <div class="space-y-6">
          <%= for sec <- secs do %>

            <!-- ══ SECCIÓN: CARRUSEL ══ -->
            <%= if sec.tipo == "carrusel" and @carrusel != [] do %>
              <div class="relative w-full -mb-14">
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
                <div class="absolute bottom-0 left-0 right-0 pointer-events-none" style="height:80px;background:linear-gradient(to top, #f9fafb 0%, transparent 100%);z-index:10;"></div>
                <%= if length(@carrusel) > 1 do %>
                  <div class="absolute flex gap-1.5" style="bottom:88px;left:50%;transform:translateX(-50%);z-index:20;">
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
            <% end %>

            <!-- ══ SECCIÓN: TIENDA PRINCIPAL (categorías + productos) ══ -->
            <%= if sec.tipo == "productos" do %>
              <div class="flex gap-3">
                <!-- Sidebar categorías -->
                <div class="flex-shrink-0 w-[72px] sticky self-start" style="top: 130px;">
                  <div id="cat-sidebar" phx-hook="ScrollCatActive"
                    style="height: calc(100vh - 130px); overflow-y: auto; position: relative; scrollbar-width: none; -ms-overflow-style: none;">
                    <%
                      n = length(@categorias)
                      cats_triple = @categorias ++ @categorias ++ @categorias
                    %>
                    <div data-cat-list data-total={n} style="display:flex;flex-direction:column;align-items:center;">
                      <%= for {cat, loop_idx} <- Enum.with_index(cats_triple) do %>
                        <% real_idx = rem(loop_idx, max(n, 1)) %>
                        <% activa = real_idx == @cat_idx %>
                        <% es_referencia = activa and loop_idx >= n and loop_idx < 2 * n %>
                        <button
                          phx-click="filtrar_categoria"
                          phx-value-categoria={cat.nombre}
                          data-active={if es_referencia, do: "true", else: "false"}
                          class="flex flex-col items-center w-full focus:outline-none"
                          style="padding:4px;background:transparent;transition:all 0.22s cubic-bezier(0.4,0,0.2,1);"
                        >
                          <div style={"width:#{if activa, do: "60px", else: "42px"};height:#{if activa, do: "60px", else: "42px"};border-radius:50%;overflow:hidden;background:transparent;border:none;box-shadow:#{if activa, do: "0 4px 12px rgba(0,0,0,0.25)", else: "none"};transition:all 0.22s cubic-bezier(0.4,0,0.2,1);opacity:#{if activa, do: "1", else: "0.5"};"}>
                            <img src={cat.imagen_url || "https://prettycore.xyz/IMAGENES/sr.j.png"} alt={cat.nombre} style="width:100%;height:100%;object-fit:cover;" />
                          </div>
                          <span style={"font-family:'Outfit',sans-serif;font-size:#{if activa, do: "10px", else: "9px"};font-weight:#{if activa, do: "600", else: "400"};letter-spacing:0.01em;color:#{if activa, do: "#111827", else: "#9ca3af"};margin-top:3px;text-align:center;line-height:1.2;transition:all 0.22s ease-out;display:block;width:100%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;"}>
                            <%= cat.nombre %>
                          </span>
                        </button>
                      <% end %>
                    </div>
                  </div>
                </div>
                <!-- Columna derecha: productos -->
                <div class="flex-1 min-w-0 relative">
                  <div class="relative md:px-[200px]" style="z-index:30;">
                    <%= if Enum.empty?(@productos) do %>
                      <div class="text-center py-20 text-gray-400">
                        <p class="text-sm font-medium">Sin productos</p>
                        <p class="text-xs mt-1">Presiona "Sincronizar" para cargar el catálogo</p>
                      </div>
                    <% else %>
                      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 2xl:grid-cols-6 gap-3">
                        <%= for producto <- @productos do %>
                          <div class="bg-white rounded-xl overflow-hidden hover:shadow-lg transition-all duration-200 flex flex-col group">
                            <div class="relative w-full aspect-square bg-gray-50 flex items-center justify-center overflow-hidden">
                              <%= if producto.imagen_url && producto.imagen_url != "" do %>
                                <img src={"#{producto.imagen_url}?t=#{DateTime.to_unix(producto.updated_at)}"} alt={producto.descripcion} class="w-full h-full object-cover" />
                              <% else %>
                                <svg class="w-10 h-10 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                                </svg>
                              <% end %>
                              <span class={"absolute top-2 left-2 inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold #{if producto.activo, do: "bg-green-500/90 text-white", else: "bg-black/40 text-white"}"}>
                                <%= if producto.activo, do: "Activo", else: "Inactivo" %>
                              </span>
                              <%= if puede_editar do %>
                                <button type="button" phx-click="edit_imagen" phx-value-codigo={producto.codigo}
                                  class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 flex items-center justify-center" title="Cambiar imagen">
                                  <span class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 bg-white/95 rounded-lg p-2 shadow-md">
                                    <svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                      <path stroke-linecap="round" stroke-linejoin="round" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                                    </svg>
                                  </span>
                                </button>
                              <% end %>
                            </div>
                            <div class="p-2.5 flex flex-col flex-1">
                              <h3 class="text-xs font-semibold text-gray-900 leading-tight line-clamp-2 mb-1"><%= producto.descripcion %></h3>
                              <div class="mt-auto pt-2 border-t border-gray-100 space-y-0.5 text-[11px]">
                                <div class="flex justify-between text-gray-400">
                                  <span>Cód.</span><span class="font-mono font-medium text-gray-600"><%= producto.codigo %></span>
                                </div>
                                <div class="flex justify-between text-gray-400">
                                  <span>Mín.</span><span class="font-medium text-gray-600"><%= producto.pzas_min_vta %> pza</span>
                                </div>
                              </div>
                              <%= if @user_role != "sysadmin" do %>
                                <div class="mt-2 flex gap-1">
                                  <button phx-click="add_to_cart" phx-value-codigo={producto.codigo}
                                    class="flex-1 flex items-center justify-center gap-1 px-2 py-1.5 bg-transparent border border-gray-900 hover:bg-blue-500 hover:border-blue-500 hover:text-white text-gray-900 text-[11px] font-medium rounded-full transition-colors">
                                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
                                  </button>
                                  <button phx-click="add_to_cart" phx-value-codigo={producto.codigo}
                                    class="flex-1 flex items-center justify-center gap-1 px-2 py-1.5 bg-gray-900 hover:bg-blue-500 text-white text-[11px] font-medium rounded-full transition-colors">
                                    Comprar
                                  </button>
                                </div>
                              <% end %>
                            </div>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: FILAS DE PRODUCTOS (top10 / favoritos / destacados) ══ -->
            <%= if sec.tipo in ["top10", "favoritos", "destacados"] do %>
              <div class="px-4 sm:px-6">
                <div class="flex items-center gap-2 mb-3">
                  <%= case sec.tipo do %>
                    <% "top10" -> %>
                      <div class="w-7 h-7 rounded-lg bg-yellow-100 flex items-center justify-center">
                        <svg class="w-4 h-4 text-yellow-600" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                      </div>
                    <% "favoritos" -> %>
                      <div class="w-7 h-7 rounded-lg bg-red-100 flex items-center justify-center">
                        <svg class="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 24 24"><path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/></svg>
                      </div>
                    <% "destacados" -> %>
                      <div class="w-7 h-7 rounded-lg bg-orange-100 flex items-center justify-center">
                        <svg class="w-4 h-4 text-orange-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 3l14 9-14 9V3z"/></svg>
                      </div>
                  <% end %>
                  <h2 class="text-base font-bold text-gray-900"><%= sec.nombre %></h2>
                </div>
                <%
                  sec_prods =
                    case (sec.config || %{}) do
                      %{"codigos" => codigos} when is_list(codigos) and codigos != [] ->
                        Enum.filter(@productos, &(&1.codigo in codigos))
                      _ ->
                        Enum.take(@productos, 10)
                    end
                %>
                <%= if Enum.empty?(sec_prods) do %>
                  <p class="text-sm text-gray-400 py-4">Sin productos disponibles</p>
                <% else %>
                  <div class="flex gap-3 overflow-x-auto pb-3 snap-x" style="scrollbar-width: thin;">
                    <%= for prod <- sec_prods do %>
                      <div class="flex-none w-36 bg-white rounded-xl overflow-hidden shadow-sm border border-gray-100 snap-start hover:shadow-md transition-shadow">
                        <div class="w-full aspect-square bg-gray-50 overflow-hidden">
                          <%= if prod.imagen_url && prod.imagen_url != "" do %>
                            <img src={prod.imagen_url} alt={prod.descripcion} class="w-full h-full object-cover" />
                          <% else %>
                            <div class="w-full h-full flex items-center justify-center">
                              <svg class="w-8 h-8 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
                            </div>
                          <% end %>
                        </div>
                        <div class="p-2">
                          <p class="text-xs font-semibold text-gray-900 line-clamp-2 leading-tight"><%= prod.descripcion %></p>
                          <p class="text-[10px] text-gray-400 font-mono mt-0.5"><%= prod.codigo %></p>
                          <%= if @user_role != "sysadmin" do %>
                            <button phx-click="add_to_cart" phx-value-codigo={prod.codigo}
                              class="mt-2 w-full py-1 bg-gray-900 hover:bg-blue-500 text-white text-[10px] font-medium rounded-full transition-colors">
                              Comprar
                            </button>
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: PUBLICIDAD ══ -->
            <%= if sec.tipo == "publicidad" do %>
              <div class="px-4 sm:px-6">
                <div class="rounded-2xl bg-gradient-to-r from-purple-600 via-violet-600 to-indigo-600 p-8 text-white relative overflow-hidden">
                  <div class="absolute top-0 right-0 w-64 h-64 rounded-full bg-white/5 -translate-y-1/2 translate-x-1/2"></div>
                  <div class="absolute bottom-0 left-0 w-40 h-40 rounded-full bg-white/5 translate-y-1/2 -translate-x-1/2"></div>
                  <div class="relative">
                    <% pub_cfg = sec.config || %{} %>
                    <h2 class="text-2xl font-bold mb-2"><%= pub_cfg["titulo"] || sec.nombre %></h2>
                    <p class="text-purple-200 text-sm max-w-md"><%= pub_cfg["subtitulo"] || "Explora nuestro catálogo completo y encuentra los mejores productos para ti." %></p>
                    <button phx-click="sync" class="mt-5 inline-flex items-center gap-2 px-5 py-2.5 bg-white text-purple-700 rounded-xl text-sm font-semibold hover:bg-purple-50 transition-colors shadow-sm">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M6 2L3 6v14a2 2 0 002 2h14a2 2 0 002-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 01-8 0"/></svg>
                      <%= pub_cfg["boton"] || "Ver catálogo" %>
                    </button>
                  </div>
                </div>
              </div>
            <% end %>

            <!-- ══ SECCIÓN: ENVÍOS ══ -->
            <%= if sec.tipo == "envios" do %>
              <div class="px-4 sm:px-6">
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
                <div class="bg-white rounded-2xl border border-gray-200 p-5 shadow-sm">
                  <h2 class="text-base font-bold text-gray-900 mb-4"><%= sec.nombre %></h2>
                  <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <%= for card <- env_cards do %>
                      <% {icon_class, icon_path} = color_icon.(card["color"] || "purple") %>
                      <div class="flex flex-col items-center text-center p-3 bg-gray-50 rounded-xl">
                        <svg class={"w-8 h-8 mb-2 #{icon_class}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                          <path stroke-linecap="round" stroke-linejoin="round" d={icon_path}/>
                        </svg>
                        <p class="text-xs font-semibold text-gray-800"><%= card["titulo"] %></p>
                        <p class="text-xs text-gray-400 mt-0.5"><%= card["descripcion"] %></p>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>

          <% end %>
        </div>
      <% end %>
      </div><!-- fin contenido -->
    </section>

    <!-- DRAWER CARRITO (solo roles no-sysadmin) -->
    <%= if @user_role != "sysadmin" and @cart_open do %>
      <div class="fixed inset-0 z-40 flex justify-end">
        <div class="absolute inset-0 bg-black/40 backdrop-blur-sm" phx-click="toggle_cart"></div>
        <div class="relative w-full max-w-sm bg-white shadow-2xl flex flex-col h-full">
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2">
              <svg class="w-5 h-5 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <h2 class="text-base font-semibold text-gray-900">Carrito</h2>
              <%= if @cart_total_items > 0 do %>
                <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-700">
                  <%= @cart_total_items %> items
                </span>
              <% end %>
            </div>
            <div class="flex items-center gap-2">
              <%= if @cart_items != [] do %>
                <button
                  phx-click="vaciar_carrito"
                  class="text-xs text-red-400 hover:text-red-600 transition-colors"
                  data-confirm="¿Vaciar el carrito?"
                >
                  Vaciar
                </button>
              <% end %>
              <button phx-click="toggle_cart" class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg transition-colors">
                <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto p-4">
            <%= if Enum.empty?(@cart_items) do %>
              <div class="flex flex-col items-center justify-center h-full text-gray-400 py-20">
                <svg class="w-14 h-14 mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <p class="text-sm font-medium">Carrito vacío</p>
                <p class="text-xs mt-1">Agrega productos desde el catálogo</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for item <- @cart_items do %>
                  <div class="flex gap-3 bg-gray-50 rounded-xl p-3 items-center">
                    <div class="w-12 h-12 rounded-lg overflow-hidden bg-white border border-gray-200 flex-shrink-0 flex items-center justify-center">
                      <%= if item.producto && item.producto.imagen_url && item.producto.imagen_url != "" do %>
                        <img src={"#{item.producto.imagen_url}?t=#{DateTime.to_unix(item.producto.updated_at)}"} class="w-full h-full object-cover" />
                      <% else %>
                        <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      <% end %>
                    </div>
                    <div class="flex-1 min-w-0">
                      <p class="text-xs font-semibold text-gray-900 truncate">
                        <%= if item.producto, do: item.producto.descripcion, else: item.producto_codigo %>
                      </p>
                      <p class="text-[11px] text-gray-400 font-mono"><%= item.producto_codigo %></p>
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad - 1}
                        class="w-6 h-6 rounded-md bg-white border border-gray-200 text-gray-500 hover:bg-red-50 hover:border-red-200 hover:text-red-500 flex items-center justify-center transition-colors text-sm font-bold">−</button>
                      <span class="w-7 text-center text-xs font-semibold text-gray-700"><%= item.cantidad %></span>
                      <button phx-click="update_cantidad" phx-value-id={item.id} phx-value-cantidad={item.cantidad + 1}
                        class="w-6 h-6 rounded-md bg-white border border-gray-200 text-gray-500 hover:bg-purple-50 hover:border-purple-200 hover:text-purple-600 flex items-center justify-center transition-colors text-sm font-bold">+</button>
                      <button phx-click="remove_from_cart" phx-value-id={item.id}
                        class="ml-1 w-6 h-6 rounded-md text-gray-300 hover:text-red-500 flex items-center justify-center transition-colors">
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <%= if @cart_items != [] do %>
            <div class="border-t border-gray-100 p-4">
              <div class="flex justify-between text-sm font-semibold text-gray-900 mb-3">
                <span>Total de productos</span>
                <span class="text-purple-600"><%= @cart_total_items %> pzas</span>
              </div>
              <div class="flex items-center gap-2 text-xs text-gray-400 bg-gray-50 rounded-lg px-3 py-2">
                <svg class="w-3.5 h-3.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Carrito guardado en base de datos
              </div>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <!-- MODAL UPLOAD IMAGEN -->
    <%= if @editing_imagen_codigo do %>
      <% producto_edit = Enum.find(@productos, &(&1.codigo == @editing_imagen_codigo)) %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="cancel_imagen"></div>
        <div class="relative w-full max-w-md bg-white rounded-2xl shadow-2xl overflow-hidden">
          <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
            <div>
              <h3 class="text-base font-semibold text-gray-900">Imagen del producto</h3>
              <%= if producto_edit do %>
                <p class="text-xs text-gray-400 mt-0.5 truncate max-w-xs"><%= producto_edit.descripcion %></p>
              <% end %>
            </div>
            <button type="button" phx-click="cancel_imagen" class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg transition-colors">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="p-5">
            <%= if producto_edit && producto_edit.imagen_url && producto_edit.imagen_url != "" do %>
              <div class="mb-4">
                <p class="text-xs font-medium text-gray-500 mb-2">Imagen actual</p>
                <img
                  src={"#{producto_edit.imagen_url}?t=#{DateTime.to_unix(producto_edit.updated_at)}"}
                  alt="Imagen actual"
                  class="w-full h-40 object-contain rounded-xl border border-gray-200 bg-gray-50"
                />
              </div>
            <% end %>

            <form phx-submit="subir_imagen" phx-change="validate_upload" id="form-upload-imagen">
              <input type="hidden" name="codigo" value={@editing_imagen_codigo} />
              <label class="block border-2 border-dashed border-gray-300 rounded-xl p-6 text-center hover:border-purple-400 transition-colors mb-4 cursor-pointer">
                <.live_file_input upload={@uploads.imagen} class="sr-only" />
                <%= if Enum.empty?(@uploads.imagen.entries) do %>
                  <svg class="w-8 h-8 text-gray-300 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <p class="text-xs text-gray-400 mb-3">JPG, PNG, WebP o GIF · Máx 10 MB</p>
                  <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-purple-50 border border-purple-200 rounded-lg text-xs font-medium text-purple-600">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                    </svg>
                    Seleccionar archivo
                  </span>
                <% else %>
                  <p class="text-xs text-purple-600 font-medium">Cambiar archivo seleccionado</p>
                <% end %>
              </label>

              <%= for entry <- @uploads.imagen.entries do %>
                <div class="mb-3 bg-gray-50 rounded-xl p-3">
                  <div class="flex items-center justify-between mb-1.5">
                    <span class="text-xs font-medium text-gray-700 truncate max-w-[200px]"><%= entry.client_name %></span>
                    <span class="text-xs text-gray-400"><%= entry.progress %>%</span>
                  </div>
                  <div class="w-full bg-gray-200 rounded-full h-1.5">
                    <div class="bg-purple-500 h-1.5 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                  </div>
                  <%= for err <- upload_errors(@uploads.imagen, entry) do %>
                    <p class="text-xs text-red-500 mt-1"><%= upload_error_to_string(err) %></p>
                  <% end %>
                </div>
              <% end %>

              <%= for err <- upload_errors(@uploads.imagen) do %>
                <p class="text-xs text-red-500 mb-2"><%= upload_error_to_string(err) %></p>
              <% end %>

              <%= if @upload_error do %>
                <div class="mb-3 px-3 py-2 bg-red-50 border border-red-200 rounded-lg">
                  <p class="text-xs text-red-600"><%= @upload_error %></p>
                </div>
              <% end %>

              <% all_done = Enum.any?(@uploads.imagen.entries) and
                            upload_errors(@uploads.imagen) == [] and
                            Enum.all?(@uploads.imagen.entries, fn e ->
                              upload_errors(@uploads.imagen, e) == []
                            end) %>
              <div class="flex gap-2 pt-2">
                <button type="button" phx-click="cancel_imagen"
                  class="flex-1 px-4 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors">
                  Cancelar
                </button>
                <button type="submit" disabled={not all_done or @uploading_imagen}
                  class={"flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium rounded-xl transition-all #{if all_done and not @uploading_imagen, do: "bg-purple-600 text-white hover:bg-purple-500", else: "bg-gray-100 text-gray-400 cursor-not-allowed"}"}>
                  <%= if @uploading_imagen do %>
                    <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                    </svg>
                    Subiendo...
                  <% else %>
                    <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                    </svg>
                    Subir imagen
                  <% end %>
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
