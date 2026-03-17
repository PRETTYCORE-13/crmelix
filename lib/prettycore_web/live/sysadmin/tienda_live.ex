defmodule PrettycoreWeb.SysAdmin.TiendaLive do
  use PrettycoreWeb, :live_view

  import PrettycoreWeb.SysAdminLayout

  alias Prettycore.Productos
  alias Prettycore.Sftp

  @max_file_size 10_000_000  # 10 MB

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "tienda")
      |> assign(:productos, [])
      |> assign(:loading, true)
      |> assign(:syncing, false)
      |> assign(:search, "")
      |> assign(:editing_imagen_codigo, nil)
      |> assign(:upload_error, nil)
      |> assign(:uploading_imagen, false)
      |> allow_upload(:imagen,
          accept: ~w(.jpg .jpeg .png .webp .gif),
          max_entries: 1,
          max_file_size: @max_file_size,
          auto_upload: true)

    if connected?(socket) do
      send(self(), :load_productos)
    end

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_productos, socket) do
    productos = Productos.list_productos()
    {:noreply, assign(socket, productos: productos, loading: false)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    productos = Productos.search_productos(q)
    {:noreply, assign(socket, search: q, productos: productos)}
  end

  @impl true
  def handle_event("sync", _, socket) do
    socket = assign(socket, syncing: true)
    send(self(), :do_sync)
    {:noreply, socket}
  end

  @impl true
  def handle_info(:do_sync, socket) do
    case Productos.sync_from_api() do
      {:ok, count} ->
        productos = Productos.list_productos()
        {:noreply,
         socket
         |> assign(syncing: false, productos: productos, search: "")
         |> put_flash(:info, "#{count} productos sincronizados")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(syncing: false)
         |> put_flash(:error, "Error al sincronizar productos")}
    end
  end

  # ── Edición de imagen ──

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
                 upload_error: "Imagen subida pero error al guardar en BD",
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

  # ── Helpers ──

  defp upload_error_to_string(:too_large),       do: "Archivo muy grande (máx 10 MB)"
  defp upload_error_to_string(:not_accepted),    do: "Tipo no permitido (jpg, png, webp, gif)"
  defp upload_error_to_string(:too_many_files),  do: "Solo se permite 1 imagen"
  defp upload_error_to_string(_),                do: "Error al cargar archivo"

  @impl true
  def render(assigns) do
    ~H"""
    <.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <section class="p-4 sm:p-6 min-h-screen bg-gray-50">
        <!-- Header -->
        <header class="mb-5">
          <div class="flex items-center justify-between gap-4">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Tienda</h1>
              <p class="text-sm text-gray-500 mt-0.5">Catálogo de productos · edición de imágenes</p>
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
                class={"inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all #{if @syncing, do: "bg-gray-100 text-gray-400 cursor-not-allowed", else: "bg-purple-600 text-white hover:bg-purple-500"}"}
              >
                <svg class={"w-4 h-4 #{if @syncing, do: "animate-spin"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <%= if @syncing, do: "Sincronizando...", else: "Sincronizar" %>
              </button>
            </div>
          </div>
        </header>

        <!-- Search -->
        <%= if not @loading do %>
          <div class="mb-5">
            <div class="relative">
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
          </div>
        <% end %>

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
          <%= if Enum.empty?(@productos) do %>
            <div class="text-center py-20 text-gray-400">
              <p class="text-sm font-medium">Sin productos</p>
              <p class="text-xs mt-1">Presiona "Sincronizar" para cargar el catálogo</p>
            </div>
          <% else %>
            <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 2xl:grid-cols-7 gap-3">
              <%= for producto <- @productos do %>
                <div class="bg-white border border-gray-200 rounded-xl overflow-hidden hover:shadow-lg hover:border-purple-300 transition-all duration-200 flex flex-col group">
                  <!-- Imagen cuadrada -->
                  <div class="relative w-full aspect-square bg-gray-50 flex items-center justify-center overflow-hidden">
                    <%= if producto.imagen_url && producto.imagen_url != "" do %>
                      <img
                        src={"#{producto.imagen_url}?t=#{DateTime.to_unix(producto.updated_at)}"}
                        alt={producto.descripcion}
                        class="w-full h-full object-cover"
                      />
                    <% else %>
                      <svg class="w-10 h-10 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                      </svg>
                    <% end %>
                    <!-- Badge estado -->
                    <span class={"absolute top-2 left-2 inline-flex items-center px-1.5 py-0.5 rounded-md text-[10px] font-semibold #{if producto.activo, do: "bg-green-500/90 text-white", else: "bg-black/40 text-white"}"}>
                      <%= if producto.activo, do: "Activo", else: "Inactivo" %>
                    </span>
                    <!-- Botón editar imagen -->
                    <button
                      type="button"
                      phx-click="edit_imagen"
                      phx-value-codigo={producto.codigo}
                      class="absolute inset-0 bg-black/0 group-hover:bg-black/20 transition-all duration-200 flex items-center justify-center"
                      title="Cambiar imagen"
                    >
                      <span class="opacity-0 group-hover:opacity-100 transition-opacity duration-200 bg-white/95 rounded-lg p-2 shadow-md">
                        <svg class="w-4 h-4 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                          <path stroke-linecap="round" stroke-linejoin="round" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                        </svg>
                      </span>
                    </button>
                  </div>

                  <!-- Info -->
                  <div class="p-2.5 flex flex-col flex-1">
                    <h3 class="text-xs font-semibold text-gray-900 leading-tight line-clamp-2 mb-1">
                      <%= producto.descripcion %>
                    </h3>
                    <div class="mt-auto pt-2 border-t border-gray-100 space-y-0.5 text-[11px]">
                      <div class="flex justify-between text-gray-400">
                        <span>Cód.</span>
                        <span class="font-mono font-medium text-gray-600"><%= producto.codigo %></span>
                      </div>
                      <div class="flex justify-between text-gray-400">
                        <span>Mín.</span>
                        <span class="font-medium text-gray-600"><%= producto.pzas_min_vta %> pza</span>
                      </div>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </section>

      <!-- ═══════════════════ MODAL UPLOAD IMAGEN ═══════════════════ -->
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
                  <img src={producto_edit.imagen_url} alt="Imagen actual" class="w-full h-40 object-contain rounded-xl border border-gray-200 bg-gray-50" />
                </div>
              <% end %>

              <form phx-submit="subir_imagen" id="form-upload-imagen-sysadmin">
                <input type="hidden" name="codigo" value={@editing_imagen_codigo} />

                <div class="relative border-2 border-dashed border-gray-300 rounded-xl p-6 text-center hover:border-gray-500 transition-colors mb-4">
                  <svg class="w-8 h-8 text-gray-300 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <p class="text-xs text-gray-400 mb-3">JPG, PNG, WebP o GIF · Máx 10 MB</p>
                  <.live_file_input upload={@uploads.imagen} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                  <span class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-gray-100 border border-gray-300 rounded-lg text-xs font-medium text-gray-700 cursor-pointer">
                    Seleccionar archivo
                  </span>
                </div>

                <%= for entry <- @uploads.imagen.entries do %>
                  <div class="mb-3 bg-gray-50 rounded-xl p-3">
                    <div class="flex items-center justify-between mb-1.5">
                      <span class="text-xs font-medium text-gray-700 truncate max-w-[200px]"><%= entry.client_name %></span>
                      <span class="text-xs text-gray-400"><%= entry.progress %>%</span>
                    </div>
                    <div class="w-full bg-gray-200 rounded-full h-1.5">
                      <div class="bg-gray-800 h-1.5 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
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
                              Enum.all?(@uploads.imagen.entries, &(&1.progress == 100)) %>
                <div class="flex gap-2 pt-2">
                  <button type="button" phx-click="cancel_imagen"
                    class="flex-1 px-4 py-2.5 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-50 transition-colors">
                    Cancelar
                  </button>
                  <button type="submit" disabled={not all_done or @uploading_imagen}
                    class={"flex-1 inline-flex items-center justify-center gap-2 px-4 py-2.5 text-sm font-medium rounded-xl transition-all #{if all_done and not @uploading_imagen, do: "bg-gray-900 text-white hover:bg-black", else: "bg-gray-100 text-gray-400 cursor-not-allowed"}"}>
                    <%= if @uploading_imagen do %>
                      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                      </svg>
                      Subiendo...
                    <% else %>
                      Subir imagen
                    <% end %>
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </.sidebar>
    """
  end
end
