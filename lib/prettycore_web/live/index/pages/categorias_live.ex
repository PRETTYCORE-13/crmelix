defmodule PrettycoreWeb.CategoriasLive do
  use PrettycoreWeb, :live_view_admin

  import PrettycoreWeb.MenuLayout

  alias Prettycore.Categorias
  alias Prettycore.Categorias.Categoria
  alias Prettycore.ProductosNativos
  alias Prettycore.Sftp

  @max_file_size 10_000_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "categorias")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
      |> assign(:categorias, [])
      |> assign(:modal, nil)            # nil | :nueva | :editar | :imagen
      |> assign(:selected, nil)         # categoria seleccionada para editar/imagen
      |> assign(:form_nombre, "")
      |> assign(:form_orden, "0")
      |> assign(:form_error, nil)
      |> assign(:upload_error, nil)
      |> assign(:uploading, false)
      |> assign(:todos_productos, [])
      |> assign(:cat_productos_codigos, MapSet.new())
      |> assign(:modal_search, "")
      |> allow_upload(:imagen,
          accept: ~w(.jpg .jpeg .png .webp .gif),
          max_entries: 1,
          max_file_size: @max_file_size,
          auto_upload: true)

    if connected?(socket), do: send(self(), :load_categorias)
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_categorias, socket) do
    {:noreply, assign(socket, categorias: Categorias.list_categorias())}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar" -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "inicio"         -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}
      "categorias"                 -> {:noreply, socket}
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

  # ── Abrir modales ──────────────────────────────────────────────────

  def handle_event("nueva", _, socket) do
    {:noreply, assign(socket, modal: :nueva, form_nombre: "", form_orden: "#{length(socket.assigns.categorias)}", form_error: nil)}
  end

  def handle_event("editar", %{"id" => id}, socket) do
    cat = Categorias.get_categoria_con_productos(id)
    todos = ProductosNativos.list_todos()
    # Productos cuyo campo categoria coincide con el nombre de esta categoría
    codigos = todos
      |> Enum.filter(&(&1.categoria == cat.nombre))
      |> Enum.map(& &1.codigo)
      |> MapSet.new()
    {:noreply, assign(socket,
      modal: :editar,
      selected: cat,
      form_nombre: cat.nombre,
      form_orden: "#{cat.orden}",
      form_error: nil,
      todos_productos: todos,
      cat_productos_codigos: codigos,
      modal_search: ""
    )}
  end

  def handle_event("edit_imagen", %{"id" => id}, socket) do
    cat = Enum.find(socket.assigns.categorias, &(&1.id == id))
    {:noreply, assign(socket, modal: :imagen, selected: cat, upload_error: nil, uploading: false)}
  end

  def handle_event("cerrar_modal", _, socket) do
    {:noreply, assign(socket, modal: nil, selected: nil, form_error: nil, upload_error: nil)}
  end

  # ── Guardar nueva categoría ────────────────────────────────────────

  def handle_event("guardar_nueva", %{"nombre" => nombre, "orden" => orden}, socket) do
    nombre = String.trim(nombre)
    if nombre == "" do
      {:noreply, assign(socket, form_error: "El nombre no puede estar vacío")}
    else
      attrs = %{nombre: nombre, orden: String.to_integer(orden)}
      case Categorias.create_categoria(attrs) do
        {:ok, _} ->
          cats = Categorias.list_categorias()
          {:noreply, assign(socket, categorias: cats, modal: nil, form_error: nil)}
        {:error, cs} ->
          msg = cs.errors |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end) |> Enum.join(", ")
          {:noreply, assign(socket, form_error: msg)}
      end
    end
  end

  # ── Guardar edición ────────────────────────────────────────────────

  def handle_event("guardar_edicion", %{"nombre" => nombre, "orden" => orden}, socket) do
    nombre = String.trim(nombre)
    if nombre == "" do
      {:noreply, assign(socket, form_error: "El nombre no puede estar vacío")}
    else
      attrs = %{nombre: nombre, orden: String.to_integer(orden)}
      with {:ok, cat} <- Categorias.update_categoria(socket.assigns.selected, attrs) do
        ProductosNativos.asignar_categoria(cat.nombre, MapSet.to_list(socket.assigns.cat_productos_codigos))
        cats = Categorias.list_categorias()
        {:noreply, assign(socket, categorias: cats, modal: nil, form_error: nil)}
      else
        {:error, cs} ->
          msg = cs.errors |> Enum.map(fn {f, {m, _}} -> "#{f}: #{m}" end) |> Enum.join(", ")
          {:noreply, assign(socket, form_error: msg)}
      end
    end
  end

  # ── Búsqueda en modal ──────────────────────────────────────────────

  def handle_event("modal_search", %{"q" => q}, socket) do
    {:noreply, assign(socket, modal_search: q)}
  end

  # ── Toggle producto en categoría ───────────────────────────────────

  def handle_event("toggle_producto", %{"codigo" => codigo}, socket) do
    codigos = socket.assigns.cat_productos_codigos
    codigos =
      if MapSet.member?(codigos, codigo),
        do: MapSet.delete(codigos, codigo),
        else: MapSet.put(codigos, codigo)
    {:noreply, assign(socket, cat_productos_codigos: codigos)}
  end

  # ── Eliminar ──────────────────────────────────────────────────────

  def handle_event("eliminar", %{"id" => id}, socket) do
    cat = Enum.find(socket.assigns.categorias, &(&1.id == id))
    if cat, do: Categorias.delete_categoria(cat)
    cats = Categorias.list_categorias()
    {:noreply, assign(socket, categorias: cats)}
  end

  # ── Upload imagen ──────────────────────────────────────────────────

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("subir_imagen", _params, socket) do
    cat = socket.assigns.selected
    entries = socket.assigns.uploads.imagen.entries

    if entries == [] do
      {:noreply, assign(socket, upload_error: "Selecciona una imagen primero")}
    else
      socket = assign(socket, uploading: true, upload_error: nil)

      results =
        consume_uploaded_entries(socket, :imagen, fn %{path: tmp_path}, entry ->
          ext = Path.extname(entry.client_name) |> String.downcase()
          content = File.read!(tmp_path)
          slug = cat.nombre |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "_")
          case Sftp.upload_categoria_image(slug, ext, content) do
            {:ok, url}       -> {:ok, {:ok, url}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case results do
        [{:ok, url}] ->
          {:ok, updated} = Categorias.update_categoria(cat, %{imagen_url: url})
          cats = Categorias.list_categorias()
          {:noreply,
           socket
           |> assign(
             categorias: cats,
             selected: updated,
             uploading: false,
             upload_error: nil,
             modal: nil
           )
           |> put_flash(:info, "✓ Imagen de \"#{cat.nombre}\" actualizada correctamente")}
        [{:error, reason}] ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error SFTP: #{inspect(reason)}")}
        _ ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error inesperado al subir imagen")}
      end
    end
  end

  # ── Render ────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <section class="flex-1 p-4 sm:p-6 min-w-0 bg-gray-50">
        <!-- Header -->
        <header class="mb-6">
          <div class="flex items-center justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Categorías</h1>
              <p class="text-sm text-gray-500 mt-0.5">Gestionar categorías de la tienda</p>
            </div>
            <button
              phx-click="nueva"
              class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-purple-600 text-white hover:bg-purple-500 transition-all shadow-sm"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
              </svg>
              Nueva categoría
            </button>
          </div>
        </header>

        <!-- Grid de categorías -->
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-4">
          <%= for cat <- @categorias do %>
            <div class="bg-white border border-gray-200 rounded-2xl overflow-hidden shadow-sm hover:shadow-md hover:border-purple-200 transition-all group flex flex-col">
              <!-- Imagen -->
              <div class="relative w-full aspect-square bg-gray-50 flex items-center justify-center overflow-hidden">
                <%= if cat.imagen_url && cat.imagen_url != "" do %>
                  <img
                    src={"#{cat.imagen_url}?t=#{DateTime.to_unix(cat.updated_at)}"}
                    alt={cat.nombre}
                    class="w-full h-full object-cover"
                  />
                <% else %>
                  <svg class="w-10 h-10 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                <% end %>
                <!-- Botón cambiar imagen (hover) -->
                <button
                  phx-click="edit_imagen"
                  phx-value-id={cat.id}
                  class="absolute inset-0 bg-black/0 group-hover:bg-black/25 transition-all flex items-center justify-center"
                >
                  <span class="opacity-0 group-hover:opacity-100 transition-opacity bg-white/95 rounded-xl px-3 py-1.5 text-xs font-semibold text-purple-700 shadow flex items-center gap-1.5">
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                      <path stroke-linecap="round" stroke-linejoin="round" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Cambiar imagen
                  </span>
                </button>
              </div>

              <!-- Info + acciones -->
              <div class="p-3 flex flex-col flex-1">
                <p class="text-sm font-semibold text-gray-900 truncate"><%= cat.nombre %></p>
                <p class="text-xs text-gray-400 mt-0.5">Orden: <%= cat.orden %></p>
                <div class="mt-auto pt-2 flex gap-1.5">
                  <button
                    phx-click="editar"
                    phx-value-id={cat.id}
                    class="flex-1 py-1.5 text-xs font-medium rounded-lg bg-gray-100 hover:bg-purple-100 hover:text-purple-700 text-gray-600 transition-colors"
                  >
                    Editar
                  </button>
                  <button
                    phx-click="eliminar"
                    phx-value-id={cat.id}
                    data-confirm={"¿Eliminar '#{cat.nombre}'?"}
                    class="px-2.5 py-1.5 text-xs font-medium rounded-lg bg-gray-100 hover:bg-red-100 hover:text-red-600 text-gray-500 transition-colors"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>

      <!-- ═══ MODAL NUEVA / EDITAR CATEGORÍA ═══ -->
      <%= if @modal in [:nueva, :editar] do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/40" phx-click="cerrar_modal"></div>
          <div class={"relative bg-white rounded-2xl shadow-2xl w-full z-10 flex flex-col #{if @modal == :editar, do: "max-w-2xl max-h-[90vh]", else: "max-w-sm"}"}>
            <div class="p-6 pb-0">
              <h2 class="text-lg font-bold text-gray-900 mb-4">
                <%= if @modal == :nueva, do: "Nueva categoría", else: "Editar categoría" %>
              </h2>
            </div>
            <form phx-submit={if @modal == :nueva, do: "guardar_nueva", else: "guardar_edicion"} class="flex flex-col flex-1 overflow-hidden">
              <div class="px-6 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Nombre</label>
                  <input
                    type="text"
                    name="nombre"
                    value={@form_nombre}
                    required
                    autofocus
                    class="w-full px-3 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                    placeholder="Ej: Bebidas"
                  />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Orden</label>
                  <input
                    type="number"
                    name="orden"
                    value={@form_orden}
                    min="0"
                    class="w-full px-3 py-2 border border-gray-300 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                  />
                </div>
                <%= if @form_error do %>
                  <p class="text-sm text-red-600"><%= @form_error %></p>
                <% end %>
              </div>

              <!-- Sección de productos (solo en editar) -->
              <%= if @modal == :editar do %>
                <div class="px-6 mt-4 flex-1 flex flex-col overflow-hidden min-h-0">
                  <div class="flex items-center justify-between mb-2">
                    <label class="text-sm font-medium text-gray-700">
                      Productos en esta categoría
                      <span class="ml-1.5 text-xs bg-purple-100 text-purple-700 px-2 py-0.5 rounded-full font-semibold">
                        <%= MapSet.size(@cat_productos_codigos) %>
                      </span>
                    </label>
                  </div>
                  <!-- Búsqueda -->
                  <div class="relative mb-2">
                    <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                    <input
                      type="text"
                      placeholder="Buscar producto..."
                      value={@modal_search}
                      phx-change="modal_search"
                      name="modal_search_input"
                      class="w-full pl-8 pr-3 py-1.5 border border-gray-200 rounded-lg text-xs focus:ring-2 focus:ring-purple-400 focus:border-transparent"
                    />
                  </div>
                  <!-- Lista scrollable -->
                  <div class="overflow-y-auto flex-1 border border-gray-100 rounded-xl divide-y divide-gray-50">
                    <%
                      term = String.downcase(@modal_search)
                      productos_filtrados =
                        if term == "" do
                          @todos_productos
                        else
                          Enum.filter(@todos_productos, fn p ->
                            String.contains?(String.downcase(p.descripcion || ""), term) or
                            String.contains?(String.downcase(p.codigo || ""), term) or
                            String.contains?(String.downcase(p.marca || ""), term)
                          end)
                        end
                    %>
                    <%= if productos_filtrados == [] do %>
                      <p class="text-center text-xs text-gray-400 py-6">Sin resultados</p>
                    <% end %>
                    <%= for producto <- productos_filtrados do %>
                      <% asignado = MapSet.member?(@cat_productos_codigos, producto.codigo) %>
                      <button
                        type="button"
                        phx-click="toggle_producto"
                        phx-value-codigo={producto.codigo}
                        class={"w-full flex items-center gap-3 px-3 py-2 text-left transition-colors hover:bg-gray-50 #{if asignado, do: "bg-purple-50/60"}"}
                      >
                        <!-- Checkbox visual -->
                        <div class={"w-4 h-4 rounded border-2 flex-shrink-0 flex items-center justify-center transition-colors #{if asignado, do: "bg-purple-600 border-purple-600", else: "border-gray-300"}"}>
                          <%= if asignado do %>
                            <svg class="w-2.5 h-2.5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3.5">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                            </svg>
                          <% end %>
                        </div>
                        <!-- Info -->
                        <div class="flex-1 min-w-0">
                          <p class={"text-xs font-medium truncate #{if asignado, do: "text-purple-900", else: "text-gray-800"}"}><%= producto.descripcion %></p>
                          <p class="text-[10px] text-gray-400">Cód. <%= producto.codigo %><%= if producto.marca && producto.marca != "", do: " · #{producto.marca}" %></p>
                        </div>
                        <%= if asignado do %>
                          <span class="text-[10px] text-purple-600 font-medium flex-shrink-0">Asignado</span>
                        <% end %>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>

              <div class="flex gap-3 p-6 pt-4">
                <button type="button" phx-click="cerrar_modal"
                  class="flex-1 py-2 rounded-xl border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50">
                  Cancelar
                </button>
                <button type="submit"
                  class="flex-1 py-2 rounded-xl bg-purple-600 text-white text-sm font-medium hover:bg-purple-500">
                  Guardar
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <!-- ═══ MODAL IMAGEN ═══ -->
      <%= if @modal == :imagen do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
          <div class="absolute inset-0 bg-black/40" phx-click="cerrar_modal"></div>
          <div class="relative bg-white rounded-2xl shadow-2xl w-full max-w-sm p-6 z-10">
            <h2 class="text-lg font-bold text-gray-900 mb-1">Imagen de categoría</h2>
            <p class="text-sm text-gray-500 mb-4"><%= @selected && @selected.nombre %></p>

            <!-- Preview actual -->
            <%= if @selected && @selected.imagen_url && @selected.imagen_url != "" do %>
              <div class="w-24 h-24 mx-auto rounded-2xl overflow-hidden border-2 border-purple-200 mb-4">
                <img src={"#{@selected.imagen_url}?t=#{DateTime.to_unix(@selected.updated_at)}"} class="w-full h-full object-cover" />
              </div>
            <% end %>

            <form phx-submit="subir_imagen" phx-change="validate_upload">
              <div class="mb-4">
                <label class="flex flex-col items-center justify-center w-full h-28 border-2 border-dashed border-purple-300 rounded-xl cursor-pointer bg-purple-50 hover:bg-purple-100 transition-colors">
                  <svg class="w-8 h-8 text-purple-400 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
                  </svg>
                  <span class="text-xs text-purple-500 font-medium">Seleccionar imagen</span>
                  <.live_file_input upload={@uploads.imagen} id="img-input-categoria" phx-hook="ImageCompressor" class="sr-only" />
                </label>
              </div>

              <!-- Preview de archivo seleccionado -->
              <%= for entry <- @uploads.imagen.entries do %>
                <div class="mb-3 p-3 bg-gray-50 rounded-xl">
                  <div class="flex items-center gap-3 mb-2">
                    <svg class="w-5 h-5 text-purple-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <span class="text-xs text-gray-700 truncate flex-1"><%= entry.client_name %></span>
                    <span class="text-xs text-purple-500 font-medium flex-shrink-0"><%= entry.progress %>%</span>
                    <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500 flex-shrink-0">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                  <!-- Barra de progreso -->
                  <div class="w-full bg-gray-200 rounded-full h-1.5 overflow-hidden">
                    <div
                      class={"h-1.5 rounded-full transition-all duration-300 #{if entry.progress == 100, do: "bg-green-500", else: "bg-purple-500"}"}
                      style={"width: #{entry.progress}%"}
                    ></div>
                  </div>
                </div>
                <%= for err <- upload_errors(@uploads.imagen, entry) do %>
                  <p class="text-xs text-red-500 mb-2"><%= err %></p>
                <% end %>
              <% end %>

              <%= if @upload_error do %>
                <p class="text-sm text-red-600 mb-3"><%= @upload_error %></p>
              <% end %>

              <div class="flex gap-3">
                <button type="button" phx-click="cerrar_modal"
                  class="flex-1 py-2 rounded-xl border border-gray-300 text-sm font-medium text-gray-700 hover:bg-gray-50">
                  Cancelar
                </button>
                <% ready = Enum.any?(@uploads.imagen.entries) and
                           Enum.all?(@uploads.imagen.entries, &(&1.progress == 100)) and
                           upload_errors(@uploads.imagen) == [] and
                           Enum.all?(@uploads.imagen.entries, &(upload_errors(@uploads.imagen, &1) == [])) %>
                <button
                  type="submit"
                  disabled={not ready or @uploading}
                  class={[
                    "flex-1 py-2 rounded-xl text-sm font-medium transition-all",
                    if(ready and not @uploading,
                      do: "bg-purple-600 text-white hover:bg-purple-500",
                      else: "bg-gray-100 text-gray-400 cursor-not-allowed")
                  ]}
                >
                  <%= if @uploading, do: "Subiendo...", else: "Subir imagen" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </section>
    </div>
    """
  end
end
