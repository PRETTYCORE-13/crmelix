defmodule PrettycoreWeb.ProductosNativosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.ProductosNativos
  alias Prettycore.ProductosNativos.ProductoNativo
  alias Prettycore.Sftp
  alias Prettycore.Categorias
  alias Prettycore.SuperCategorias

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "productos_nativos")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:productos, [])
     |> assign(:search, "")
     |> assign(:modal, nil)          # nil | :nuevo | :editar
     |> assign(:selected, nil)
     |> assign(:form_codigo, "")
     |> assign(:form_descripcion, "")
     |> assign(:form_desc_corta, "")
     |> assign(:form_precio, "0")
     |> assign(:form_stock, "")
     |> assign(:form_unidad, "PZA")
     |> assign(:form_marca, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_categoria, "")
     |> assign(:form_super_categoria, "")
     |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 == "Todos")))
     |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
     |> assign(:form_imagen_url, "")
     |> assign(:form_error, nil)
     |> assign(:upload_error, nil)
     |> assign(:uploading, false)
     |> allow_upload(:imagen,
         accept: ~w(.jpg .jpeg .png .webp .gif),
         max_entries: 1,
         max_file_size: 10_000_000)
     |> load_productos()}
  end

  defp load_productos(socket) do
    q = socket.assigns[:search] || ""
    productos = if q == "", do: ProductosNativos.list_todos(), else: ProductosNativos.search(q)
    assign(socket, :productos, productos)
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
      "lista_productos"            -> {:noreply, socket}
      "productos_nativos"          -> {:noreply, socket}
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
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Búsqueda ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_productos()}
  end

  # ── Modales ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("nuevo", _, socket) do
    {:noreply, socket
     |> assign(:modal, :nuevo)
     |> assign(:selected, nil)
     |> assign(:form_codigo, ProductosNativos.next_codigo())
     |> assign(:form_descripcion, "")
     |> assign(:form_desc_corta, "")
     |> assign(:form_precio, "0")
     |> assign(:form_stock, "")
     |> assign(:form_unidad, "PZA")
     |> assign(:form_marca, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_categoria, "")
     |> assign(:form_super_categoria, "")
     |> assign(:form_imagen_url, "")
     |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 == "Todos")))
     |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
     |> assign(:form_error, nil)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("editar", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        {:noreply, socket
         |> assign(:modal, :editar)
         |> assign(:selected, p)
         |> assign(:form_codigo, p.codigo)
         |> assign(:form_descripcion, p.descripcion)
         |> assign(:form_desc_corta, p.desc_corta || "")
         |> assign(:form_precio, to_string(p.precio_base))
         |> assign(:form_stock, if(p.stock, do: to_string(p.stock), else: ""))
         |> assign(:form_unidad, p.unidad || "PZA")
         |> assign(:form_marca, p.marca || "")
         |> assign(:form_notas, p.notas || "")
         |> assign(:form_activo, p.activo)
         |> assign(:form_categoria, p.categoria || "")
         |> assign(:form_super_categoria, p.super_categoria || "")
         |> assign(:form_imagen_url, p.imagen_url || "")
         |> assign(:categorias_list, Categorias.list_categorias() |> Enum.map(& &1.nombre) |> Enum.reject(&(&1 == "Todos")))
         |> assign(:super_categorias_list, SuperCategorias.list_super_categorias() |> Enum.map(& &1.nombre))
         |> assign(:form_error, nil)
         |> assign(:upload_error, nil)}
    end
  end

  @impl true
  def handle_event("cerrar_modal", _, socket) do
    {:noreply, assign(socket, modal: nil, selected: nil, form_error: nil, upload_error: nil)}
  end

  @impl true
  def handle_event("toggle_activo_form", _, socket) do
    {:noreply, update(socket, :form_activo, &(not &1))}
  end

  # ── Guardar ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", params, socket) do
    codigo = String.trim(params["codigo"] || socket.assigns.form_codigo)

    # Subir imagen si hay archivo seleccionado
    imagen_url =
      case socket.assigns.uploads.imagen.entries do
        [entry | _] ->
          results = consume_uploaded_entries(socket, :imagen, fn %{path: tmp_path}, _e ->
            ext     = Path.extname(entry.client_name)
            content = File.read!(tmp_path)
            Sftp.upload_producto_nativo_image(codigo, ext, content)
          end)
          case results do
            [url] when is_binary(url) -> url
            _                        -> socket.assigns.form_imagen_url
          end
        [] ->
          socket.assigns.form_imagen_url
      end

    attrs = %{
      "codigo"          => codigo,
      "descripcion"     => String.trim(params["descripcion"] || ""),
      "desc_corta"      => String.trim(params["desc_corta"] || ""),
      "precio_base"     => parse_float(params["precio_base"]),
      "unidad"          => String.trim(params["unidad"] || "PZA"),
      "marca"           => String.trim(params["marca"] || ""),
      "notas"           => String.trim(params["notas"] || ""),
      "activo"          => socket.assigns.form_activo,
      "categoria"       => nilify(params["categoria"]),
      "super_categoria" => nilify(params["super_categoria"]),
      "imagen_url"      => nilify(imagen_url)
    }

    result =
      case socket.assigns.modal do
        :nuevo  -> ProductosNativos.crear(attrs)
        :editar -> ProductosNativos.actualizar(socket.assigns.selected, attrs)
      end

    case result do
      {:ok, _} ->
        {:noreply, socket |> assign(:modal, nil) |> assign(:selected, nil) |> load_productos()}

      {:error, changeset} ->
        error = changeset.errors
          |> Enum.map(fn {k, {msg, _}} -> "#{k}: #{msg}" end)
          |> Enum.join(", ")
        {:noreply, assign(socket, :form_error, error)}
    end
  end

  # ── Eliminar ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("eliminar", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        ProductosNativos.eliminar(p)
        {:noreply, load_productos(socket)}
    end
  end

  # ── Toggle activo rápido ─────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_activo", %{"codigo" => codigo}, socket) do
    case ProductosNativos.get(codigo) do
      nil -> {:noreply, socket}
      p ->
        ProductosNativos.actualizar(p, %{"activo" => !p.activo})
        {:noreply, load_productos(socket)}
    end
  end

  # ── Upload imagen ─────────────────────────────────────────────────────────────

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0
  defp parse_float(v) do
    case Float.parse(to_string(v)) do
      {f, _} -> f
      :error  -> 0.0
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(v) do
    case Integer.parse(to_string(v)) do
      {i, _} -> i
      :error  -> nil
    end
  end

  defp nilify(nil), do: nil
  defp nilify(""), do: nil
  defp nilify(v), do: String.trim(v)

  # ── Template ──────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <div class="flex-1 p-6 min-w-0">
      <!-- Encabezado -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h1 class="text-xl font-bold text-gray-900">Productos Nativos</h1>
          <p class="text-sm text-gray-400 mt-0.5">
            Productos creados directamente en esta app — aparecen en la tienda junto con los de la API.
          </p>
        </div>
        <button
          phx-click="nuevo"
          class="inline-flex items-center gap-2 px-4 py-2 bg-gray-900 hover:bg-black text-white text-sm font-semibold rounded-xl transition-colors"
        >
          <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
          </svg>
          Nuevo Producto
        </button>
      </div>

      <!-- Buscador -->
      <div class="mb-4">
        <input
          type="text"
          phx-keyup="search"
          phx-debounce="300"
          name="q"
          value={@search}
          placeholder="Buscar por código o descripción…"
          class="w-full text-sm rounded-xl border border-gray-200 px-4 py-2.5 focus:outline-none focus:ring-2 focus:ring-gray-900"
        />
      </div>

      <!-- Tabla -->
      <%= if @productos == [] do %>
        <div class="text-center py-16 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10" />
          </svg>
          <p class="text-sm font-medium">Sin productos nativos todavía</p>
          <p class="text-xs mt-1">Crea tu primer producto con el botón de arriba.</p>
        </div>
      <% else %>
        <div class="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
          <table class="w-full text-sm">
            <thead class="bg-gray-50 border-b border-gray-100">
              <tr>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Imagen</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Código</th>
                <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Descripción</th>
                <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Precio</th>
                <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Stock</th>
                <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Activo</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-50">
              <%= for p <- @productos do %>
                <tr class="hover:bg-gray-50 transition-colors">
                  <!-- Imagen -->
                  <td class="px-4 py-3">
                    <div class="w-10 h-10 rounded-lg overflow-hidden bg-gray-100 border border-gray-200 flex items-center justify-center">
                      <%= if p.imagen_url && p.imagen_url != "" do %>
                        <img src={p.imagen_url} class="w-full h-full object-cover" />
                      <% else %>
                        <svg class="w-5 h-5 text-gray-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      <% end %>
                    </div>
                  </td>
                  <!-- Código -->
                  <td class="px-4 py-3">
                    <span class="font-mono text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded"><%= p.codigo %></span>
                  </td>
                  <!-- Descripción -->
                  <td class="px-4 py-3">
                    <p class="font-medium text-gray-900 truncate max-w-xs"><%= p.descripcion %></p>
                    <%= if p.desc_corta && p.desc_corta != "" do %>
                      <p class="text-xs text-gray-400 mt-0.5"><%= p.desc_corta %></p>
                    <% end %>
                  </td>
                  <!-- Precio -->
                  <td class="px-4 py-3 text-right">
                    <span class="font-semibold text-green-600">$<%= :erlang.float_to_binary(p.precio_base / 1, decimals: 2) %></span>
                  </td>
                  <!-- Stock -->
                  <td class="px-4 py-3 text-center">
                    <%= if p.stock do %>
                      <span class={"text-xs font-semibold px-2 py-0.5 rounded-full " <> if p.stock > 0, do: "bg-emerald-100 text-emerald-700", else: "bg-red-100 text-red-600"}>
                        <%= p.stock %>
                      </span>
                    <% else %>
                      <span class="text-xs text-gray-300">—</span>
                    <% end %>
                  </td>
                  <!-- Activo -->
                  <td class="px-4 py-3 text-center">
                    <button
                      phx-click="toggle_activo"
                      phx-value-codigo={p.codigo}
                      class={"relative inline-flex h-6 w-11 items-center rounded-full transition-colors " <> if p.activo, do: "bg-emerald-500", else: "bg-gray-200"}
                    >
                      <span class={"inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform " <> if p.activo, do: "translate-x-6", else: "translate-x-1"} />
                    </button>
                  </td>
                  <!-- Acciones -->
                  <td class="px-4 py-3">
                    <div class="flex items-center gap-1 justify-end">
                      <button
                        phx-click="editar"
                        phx-value-codigo={p.codigo}
                        class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg hover:bg-gray-100 transition-colors"
                        title="Editar"
                      >
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                        </svg>
                      </button>
                      <button
                        phx-click="eliminar"
                        phx-value-codigo={p.codigo}
                        data-confirm={"¿Eliminar #{p.descripcion}?"}
                        class="p-1.5 text-gray-400 hover:text-red-500 rounded-lg hover:bg-red-50 transition-colors"
                        title="Eliminar"
                      >
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>

    <!-- ═══════════════════ MODAL CREAR / EDITAR ═══════════════════ -->
    <%= if @modal in [:nuevo, :editar] do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="cerrar_modal"></div>
        <div class="relative w-full max-w-lg bg-white rounded-2xl shadow-2xl overflow-hidden">

          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
            <h2 class="text-base font-semibold text-gray-900">
              <%= if @modal == :nuevo, do: "Nuevo Producto", else: "Editar Producto" %>
            </h2>
            <button phx-click="cerrar_modal" class="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg">
              <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Error -->
          <%= if @form_error do %>
            <div class="mx-6 mt-4 p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl">
              <%= @form_error %>
            </div>
          <% end %>

          <!-- Form -->
          <form phx-submit="guardar" phx-change="validate_upload" class="px-6 py-5 space-y-4 overflow-y-auto max-h-[82vh]">

            <!-- Imagen (siempre arriba) -->
            <div>
              <div class="relative w-full h-44 rounded-2xl overflow-hidden">
                <.live_file_input upload={@uploads.imagen}
                  id="img-input-producto-nativo"
                  phx-hook="ImageCompressor"
                  class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" />

                <%= cond do %>
                  <% @uploads.imagen.entries != [] -> %>
                    <div class="w-full h-full border-2 border-blue-300 bg-blue-50 rounded-2xl flex flex-col items-center justify-center gap-2 pointer-events-none">
                      <svg class="w-8 h-8 text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                      <span class="text-xs font-medium text-blue-600 px-4 truncate w-full text-center">
                        <%= List.first(@uploads.imagen.entries).client_name %>
                      </span>
                      <span class="text-[10px] text-blue-400">Se subirá al guardar</span>
                    </div>

                  <% @form_imagen_url && @form_imagen_url != "" -> %>
                    <img src={@form_imagen_url} class="w-full h-full object-cover pointer-events-none" />
                    <div class="absolute inset-0 bg-black/20 flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity pointer-events-none">
                      <div class="w-10 h-10 bg-white/90 rounded-full flex items-center justify-center">
                        <svg class="w-5 h-5 text-gray-800" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                        </svg>
                      </div>
                    </div>

                  <% true -> %>
                    <div class="w-full h-full border-2 border-dashed border-gray-300 rounded-2xl flex flex-col items-center justify-center gap-2 pointer-events-none">
                      <div class="relative">
                        <svg class="w-12 h-12 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                        </svg>
                        <div class="absolute -top-1 -right-1 w-6 h-6 bg-gray-900 rounded-full flex items-center justify-center">
                          <span class="text-white text-sm font-bold leading-none">+</span>
                        </div>
                      </div>
                      <span class="text-xs text-gray-400">Clic para agregar imagen</span>
                    </div>
                <% end %>
              </div>
              <%= if @upload_error do %>
                <p class="text-xs text-red-500 mt-1.5"><%= @upload_error %></p>
              <% end %>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Código *
                </label>
                <input
                  type="text"
                  name="codigo"
                  value={@form_codigo}
                  readonly
                  class="w-full text-sm rounded-lg border px-3 py-2 bg-gray-50 border-gray-200 text-gray-500 focus:outline-none"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                  Precio Base *
                </label>
                <input
                  type="number"
                  name="precio_base"
                  value={@form_precio}
                  step="0.01"
                  min="0"
                  required
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                Descripción *
              </label>
              <input
                type="text"
                name="descripcion"
                value={@form_descripcion}
                placeholder="Nombre completo del producto"
                required
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
              />
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                Descripción Corta
              </label>
              <input
                type="text"
                name="desc_corta"
                value={@form_desc_corta}
                placeholder="Subtítulo breve (opcional)"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
              />
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Unidad</label>
                <input
                  type="text"
                  name="unidad"
                  value={@form_unidad}
                  placeholder="PZA"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Marca</label>
                <input
                  type="text"
                  name="marca"
                  value={@form_marca}
                  placeholder="Opcional"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900"
                />
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Categoría</label>
                <select name="categoria"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 bg-white">
                  <option value="">— Sin categoría —</option>
                  <%= for c <- @categorias_list do %>
                    <option value={c} selected={c == @form_categoria}><%= c %></option>
                  <% end %>
                </select>
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Super Categoría</label>
                <select name="super_categoria"
                  class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 bg-white">
                  <option value="">— Sin super categoría —</option>
                  <%= for sc <- @super_categorias_list do %>
                    <option value={sc} selected={sc == @form_super_categoria}><%= sc %></option>
                  <% end %>
                </select>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">Notas</label>
              <textarea
                name="notas"
                rows="2"
                placeholder="Observaciones internas (no se muestran al cliente)"
                class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 resize-none"
              ><%= @form_notas %></textarea>
            </div>

            <!-- Activo toggle -->
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-700">Visible en tienda</p>
                <p class="text-xs text-gray-400">Si está activo, se muestra en el catálogo.</p>
              </div>
              <button
                type="button"
                phx-click="toggle_activo_form"
                class={"relative inline-flex h-7 w-14 items-center rounded-full transition-colors " <> if @form_activo, do: "bg-emerald-500", else: "bg-gray-200"}
              >
                <span class={"inline-block h-5 w-5 transform rounded-full bg-white shadow transition-transform " <> if @form_activo, do: "translate-x-8", else: "translate-x-1"} />
                <span class={"absolute text-[10px] font-bold select-none " <> if @form_activo, do: "left-1.5 text-white", else: "right-1.5 text-gray-500"}>
                  <%= if @form_activo, do: "SÍ", else: "NO" %>
                </span>
              </button>
            </div>

            <!-- Footer botones -->
            <div class="flex justify-end gap-3 pt-2 border-t border-gray-100">
              <button
                type="button"
                phx-click="cerrar_modal"
                class="px-5 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors"
              >
                Cancelar
              </button>
              <button
                type="submit"
                class="px-5 py-2 text-sm font-semibold text-white bg-gray-900 hover:bg-black rounded-xl transition-colors"
              >
                <%= if @modal == :nuevo, do: "Crear Producto", else: "Guardar Cambios" %>
              </button>
            </div>
          </form>
        </div>
      </div>
    <% end %>
    </div>
    """
  end
end
