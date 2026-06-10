defmodule PrettycoreWeb.CarruselLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Carrusel
  alias Prettycore.Sftp

  @max_file_size 10_000_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "carrusel")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
      |> assign(:imagenes, [])
      |> assign(:upload_error, nil)
      |> assign(:uploading, false)
      |> assign(:titulo_input, "")
      |> allow_upload(:imagen,
          accept: ~w(.jpg .jpeg .png .webp .gif),
          max_entries: 1,
          max_file_size: @max_file_size,
          auto_upload: true)

    if connected?(socket), do: send(self(), :load_imagenes)
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_imagenes, socket) do
    {:noreply, assign(socket, imagenes: Carrusel.list_all())}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "carrusel")
  end

  @impl true
  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("set_titulo", %{"titulo" => titulo}, socket) do
    {:noreply, assign(socket, titulo_input: titulo)}
  end

  @impl true
  def handle_event("subir_imagen", %{"titulo" => titulo}, socket) do
    entries = socket.assigns.uploads.imagen.entries

    if entries == [] do
      {:noreply, assign(socket, upload_error: "Selecciona una imagen primero")}
    else
      socket = assign(socket, uploading: true, upload_error: nil)

      now_ts = System.system_time(:second)

      results =
        consume_uploaded_entries(socket, :imagen, fn %{path: tmp_path}, entry ->
          ext = Path.extname(entry.client_name) |> String.downcase()
          content = File.read!(tmp_path)
          filename = "carrusel_#{now_ts}"
          case Sftp.upload_carrusel_image(filename, ext, content) do
            {:ok, url}       -> {:ok, {:ok, url}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case results do
        [{:ok, url}] ->
          # Borrar imagen anterior de FTP y BD antes de guardar la nueva
          Enum.each(socket.assigns.imagenes, fn img ->
            old_url = img.url
            Task.start(fn -> Sftp.delete_by_url(old_url) end)
            Carrusel.delete_imagen(img)
          end)
          titulo_val = String.trim(titulo)
          {:ok, _} = Carrusel.create_imagen(%{url: url, titulo: if(titulo_val == "", do: nil, else: titulo_val), orden: 0})
          imagenes = Carrusel.list_all()
          {:noreply,
           socket
           |> assign(imagenes: imagenes, uploading: false, upload_error: nil, titulo_input: "")
           |> put_flash(:info, "✓ Imagen actualizada")}
        [{:error, reason}] ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error SFTP: #{inspect(reason)}")}
        _ ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error inesperado")}
      end
    end
  end

  @impl true
  def handle_event("toggle_activo", %{"id" => id}, socket) do
    img = Enum.find(socket.assigns.imagenes, &(&1.id == id))
    if img, do: Carrusel.toggle_activo(img)
    {:noreply, assign(socket, imagenes: Carrusel.list_all())}
  end

  @impl true
  def handle_event("eliminar", %{"id" => id}, socket) do
    img = Enum.find(socket.assigns.imagenes, &(&1.id == id))
    if img do
      old_url = img.url
      Task.start(fn -> Sftp.delete_by_url(old_url) end)
      Carrusel.delete_imagen(img)
    end
    {:noreply, assign(socket, imagenes: Carrusel.list_all())}
  end

  @impl true
  def handle_event("editar_titulo", %{"id" => id, "titulo" => titulo}, socket) do
    img = Enum.find(socket.assigns.imagenes, &(&1.id == id))
    if img do
      titulo_val = String.trim(titulo)
      Carrusel.update_imagen(img, %{titulo: if(titulo_val == "", do: nil, else: titulo_val)})
    end
    {:noreply, assign(socket, imagenes: Carrusel.list_all())}
  end

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
            <h1 class="text-2xl font-bold text-gray-900">Anuncio</h1>
            <p class="text-sm text-gray-500 mt-0.5">Imagen de anuncio en la tienda (solo una activa)</p>
          </div>
        </div>
      </header>

      <!-- Formulario de subida -->
      <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 mb-6">
        <h2 class="text-sm font-semibold text-gray-700 mb-4"><%= if @imagenes == [], do: "Subir imagen de anuncio", else: "Reemplazar imagen actual" %></h2>
        <form phx-submit="subir_imagen" phx-change="validate_upload">
          <!-- Título opcional -->
          <div class="mb-3">
            <label class="block text-xs font-medium text-gray-500 mb-1">Título (opcional)</label>
            <input
              type="text"
              name="titulo"
              value={@titulo_input}
              placeholder="Ej: Promoción de verano"
              maxlength="100"
              class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-400 focus:border-transparent"
            />
          </div>

          <!-- Zona de arrastrar imagen -->
          <label class="flex flex-col items-center justify-center w-full h-32 border-2 border-dashed border-purple-300 rounded-xl cursor-pointer bg-purple-50 hover:bg-purple-100 transition-colors mb-3">
            <svg class="w-8 h-8 text-purple-400 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
            </svg>
            <span class="text-xs text-purple-500 font-medium">Seleccionar imagen</span>
            <span class="text-[10px] text-purple-400 mt-0.5">JPG, PNG, WEBP, GIF — máx 10MB</span>
            <.live_file_input upload={@uploads.imagen} id="img-input-carrusel" phx-hook="ImageCompressor" class="sr-only" />
          </label>

          <!-- Preview + progreso -->
          <%= for entry <- @uploads.imagen.entries do %>
            <div class="mb-3 p-3 bg-gray-50 rounded-xl">
              <div class="flex items-center gap-3 mb-2">
                <svg class="w-5 h-5 text-purple-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <span class="text-xs text-gray-700 truncate flex-1"><%= entry.client_name %></span>
                <span class="text-xs text-purple-500 font-medium flex-shrink-0"><%= entry.progress %>%</span>
                <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} class="text-gray-400 hover:text-red-500">
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-1.5 overflow-hidden">
                <div
                  class={"h-1.5 rounded-full transition-all duration-300 #{if entry.progress == 100, do: "bg-green-500", else: "bg-purple-500"}"}
                  style={"width: #{entry.progress}%"}
                ></div>
              </div>
            </div>
          <% end %>

          <%= if @upload_error do %>
            <p class="text-sm text-red-600 mb-3"><%= @upload_error %></p>
          <% end %>

          <% ready = Enum.any?(@uploads.imagen.entries) and
                     Enum.all?(@uploads.imagen.entries, &(&1.progress == 100)) and
                     upload_errors(@uploads.imagen) == [] and
                     @imagenes == [] %>
          <%= if @imagenes != [] do %>
            <p class="text-xs text-amber-600 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2 mb-3">
              Elimina la imagen actual antes de subir una nueva.
            </p>
          <% end %>
          <button
            type="submit"
            disabled={not ready or @uploading}
            class={[
              "w-full py-2 rounded-xl text-sm font-medium transition-all",
              if(ready and not @uploading,
                do: "bg-purple-600 text-white hover:bg-purple-500",
                else: "bg-gray-100 text-gray-400 cursor-not-allowed")
            ]}
          >
            <%= if @uploading, do: "Subiendo...", else: "Subir" %>
          </button>
        </form>
      </div>

      <!-- Lista de imágenes -->
      <%= if @imagenes == [] do %>
        <div class="text-center py-20 text-gray-400">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
          <p class="text-sm font-medium">Sin imagen de anuncio</p>
          <p class="text-xs mt-1">Sube tu imagen arriba</p>
        </div>
      <% else %>
        <div class="space-y-3">
          <%= for img <- @imagenes do %>
            <div class={"bg-white rounded-2xl border shadow-sm overflow-hidden flex gap-0 group #{if img.activo, do: "border-gray-200", else: "border-gray-100 opacity-60"}"}>
              <!-- Imagen preview -->
              <div class="w-32 sm:w-48 flex-shrink-0 bg-gray-100 relative overflow-hidden" style="aspect-ratio: 16/7;">
                <img src={img.url} alt={img.titulo || "Carrusel"} class="w-full h-full object-cover" />
              </div>
              <!-- Info + acciones -->
              <div class="flex-1 p-4 flex flex-col justify-between min-w-0">
                <div class="flex items-start justify-between gap-2">
                  <div class="min-w-0">
                    <form phx-submit="editar_titulo" phx-value-id={img.id} class="flex items-center gap-2">
                      <input
                        type="text"
                        name="titulo"
                        value={img.titulo || ""}
                        placeholder="Sin título"
                        maxlength="100"
                        class="text-sm font-medium text-gray-800 bg-transparent border-b border-transparent hover:border-gray-200 focus:border-purple-400 focus:outline-none px-0 py-0.5 w-full"
                      />
                      <button type="submit" class="text-[10px] text-gray-400 hover:text-purple-600 flex-shrink-0">Guardar</button>
                    </form>
                  </div>
                  <!-- Estado activo -->
                  <button
                    phx-click="toggle_activo"
                    phx-value-id={img.id}
                    class={"flex-shrink-0 px-2.5 py-1 rounded-lg text-[11px] font-medium transition-colors #{if img.activo, do: "bg-green-100 text-green-700 hover:bg-green-200", else: "bg-gray-100 text-gray-500 hover:bg-gray-200"}"}
                  >
                    <%= if img.activo, do: "Activo", else: "Inactivo" %>
                  </button>
                </div>
                <!-- Controles -->
                <div class="flex items-center gap-1.5 mt-3">
                  <button
                    phx-click="eliminar"
                    phx-value-id={img.id}
                    data-confirm="¿Eliminar esta imagen del anuncio?"
                    class="p-1.5 rounded-lg bg-gray-50 hover:bg-red-100 text-gray-400 hover:text-red-600 transition-colors ml-auto"
                    title="Eliminar"
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
      <% end %>
    </section>
    </div>
    """
  end
end
