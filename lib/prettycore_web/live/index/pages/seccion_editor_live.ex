defmodule PrettycoreWeb.SeccionEditorLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Secciones
  alias Prettycore.ProductosNativos
  alias Prettycore.Sftp

  @default_cards [
    %{"titulo" => "Envío rápido",  "descripcion" => "Entrega en 24-48h",         "color" => "purple"},
    %{"titulo" => "Compra segura", "descripcion" => "Protección garantizada",    "color" => "green"},
    %{"titulo" => "Devoluciones",  "descripcion" => "30 días sin preguntas",     "color" => "blue"},
    %{"titulo" => "Soporte 24/7",  "descripcion" => "Siempre disponible",        "color" => "orange"},
  ]

  @pub_presets [
    %{label: "Morado",  c1: "#9333ea", c2: "#4f46e5"},
    %{label: "Azul",    c1: "#2563eb", c2: "#06b6d4"},
    %{label: "Verde",   c1: "#059669", c2: "#14b8a6"},
    %{label: "Rojo",    c1: "#dc2626", c2: "#ec4899"},
    %{label: "Naranja", c1: "#f97316", c2: "#eab308"},
    %{label: "Rosa",    c1: "#db2777", c2: "#9333ea"},
    %{label: "Oscuro",  c1: "#111827", c2: "#374151"},
    %{label: "Noche",   c1: "#1e1b4b", c2: "#312e81"},
  ]

  @impl true
  def mount(%{"tipo" => tipo}, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "seccion_#{tipo}")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
      |> assign(:tipo, tipo)
      |> assign(:seccion, nil)
      |> assign(:config, %{})
      |> assign(:productos, [])
      |> assign(:search, "")
      |> assign(:guardando, false)
      |> assign(:saved, false)
      |> assign(:pub_presets, @pub_presets)
      |> assign(:promo_secciones, [])
      |> assign(:promo_configs, %{})
      |> assign(:promo_tab, "destacados")
      |> assign(:slides_list, [])
      |> assign(:nueva_imagen_url, "")
      |> assign(:nueva_imagen_titulo, "")
      |> assign(:uploading, false)
      |> assign(:upload_error, nil)
      |> allow_upload(:imagen_carrusel,
          accept: ~w(.jpg .jpeg .png .gif .webp),
          max_entries: 1,
          max_file_size: 10_000_000,
          auto_upload: true)

    if connected?(socket), do: send(self(), :load_data)
    {:ok, socket}
  end

  @impl true
  def handle_info(:load_data, socket) do
    tipo = socket.assigns.tipo
    # list_secciones triggers auto-seeding of missing section tipos
    Secciones.list_secciones()
    seccion = Secciones.get_seccion_by_tipo(tipo)
    config  = (seccion && seccion.config) || %{}

    {promo_configs, slides_list} =
      if tipo == "ofertas" do
        p_configs = %{
          "top10"      => config["top10"]      || %{},
          "favoritos"  => config["favoritos"]  || %{},
          "destacados" => config["destacados"] || %{}
        }
        slides =
          case config["slides_orden"] do
            list when is_list(list) and list != [] -> list
            _ ->
              ~w(top10 favoritos destacados)
              |> Enum.map(&%{"kind" => "seccion", "tipo" => &1})
          end
        {p_configs, slides}
      else
        {%{}, []}
      end

    {:noreply, assign(socket,
      seccion: seccion,
      config: config,
      productos: [],
      promo_secciones: [],
      promo_configs: promo_configs,
      slides_list: slides_list
    )}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket)
  end

  # ── Productos section: toggle individual product ──────────────────────

  @impl true
  def handle_event("set_promo_tab", %{"tipo" => tipo}, socket) do
    {:noreply, assign(socket, promo_tab: tipo, search: "")}
  end

  @impl true
  def handle_event("toggle_producto", %{"codigo" => codigo}, socket) do
    tab    = socket.assigns.promo_tab
    cfg    = Map.get(socket.assigns.promo_configs, tab, %{})
    codigos = get_codigos(cfg)
    codigos = if codigo in codigos, do: List.delete(codigos, codigo), else: codigos ++ [codigo]
    cfg    = Map.put(cfg, "codigos", codigos)
    promo_configs = Map.put(socket.assigns.promo_configs, tab, cfg)
    {:noreply, socket |> assign(promo_configs: promo_configs) |> autosave_ofertas()}
  end

  @impl true
  def handle_event("search", %{"value" => q}, socket) do
    {:noreply, assign(socket, search: q)}
  end

  # ── Publicidad section ────────────────────────────────────────────────

  @impl true
  def handle_event("update_pub", %{"field" => field, "value" => value}, socket) do
    if socket.assigns.tipo == "ofertas" do
      tab = socket.assigns.promo_tab
      cfg = Map.get(socket.assigns.promo_configs, tab, %{}) |> Map.put(field, value)
      socket = assign(socket, promo_configs: Map.put(socket.assigns.promo_configs, tab, cfg))
      {:noreply, autosave_ofertas(socket)}
    else
      {:noreply, socket |> assign(config: Map.put(socket.assigns.config, field, value)) |> autosave()}
    end
  end

  @impl true
  def handle_event("sec_color", %{"color" => color}, socket) do
    if socket.assigns.tipo == "ofertas" do
      tab = socket.assigns.promo_tab
      cfg = Map.get(socket.assigns.promo_configs, tab, %{}) |> Map.put("color", color)
      socket = assign(socket, promo_configs: Map.put(socket.assigns.promo_configs, tab, cfg))
      {:noreply, autosave_ofertas(socket)}
    else
      {:noreply, socket |> assign(config: Map.put(socket.assigns.config, "color", color)) |> autosave()}
    end
  end

  @impl true
  def handle_event("sec_color_custom", %{"color" => color}, socket) do
    if socket.assigns.tipo == "ofertas" do
      tab = socket.assigns.promo_tab
      cfg = Map.get(socket.assigns.promo_configs, tab, %{}) |> Map.put("color", color)
      socket = assign(socket, promo_configs: Map.put(socket.assigns.promo_configs, tab, cfg))
      {:noreply, autosave_ofertas(socket)}
    else
      {:noreply, socket |> assign(config: Map.put(socket.assigns.config, "color", color)) |> autosave()}
    end
  end

  @impl true
  def handle_event("pub_preset", %{"c1" => c1, "c2" => c2}, socket) do
    config = socket.assigns.config |> Map.put("color1", c1) |> Map.put("color2", c2)
    {:noreply, socket |> assign(config: config) |> autosave()}
  end

  @impl true
  def handle_event("pub_colors", %{"color1" => c1, "color2" => c2}, socket) do
    config = socket.assigns.config |> Map.put("color1", c1) |> Map.put("color2", c2)
    {:noreply, socket |> assign(config: config) |> autosave()}
  end

  # ── Envios section ────────────────────────────────────────────────────

  @impl true
  def handle_event("update_card", %{"idx" => idx_str, "field" => field, "value" => value}, socket) do
    idx   = String.to_integer(idx_str)
    cards = get_cards(socket.assigns.config)
    card  = cards |> Enum.at(idx) |> Map.put(field, value)
    cards = List.replace_at(cards, idx, card)
    {:noreply, socket |> assign(config: Map.put(socket.assigns.config, "cards", cards)) |> autosave()}
  end

  # ── Carrusel de Ofertas: imagen slides ───────────────────────────────

  @impl true
  def handle_event("update_nueva_imagen", params, socket) do
    titulo = params["titulo"] || params["value"] || socket.assigns.nueva_imagen_titulo
    {:noreply, assign(socket, nueva_imagen_titulo: titulo)}
  end

  @impl true
  # Agregar por URL manual
  def handle_event("agregar_imagen", params, socket) do
    url    = String.trim(params["url"] || socket.assigns.nueva_imagen_url)
    titulo = String.trim(params["titulo"] || socket.assigns.nueva_imagen_titulo)
    if url != "" do
      nuevo       = %{"kind" => "imagen", "url" => url, "titulo" => titulo}
      slides_list = socket.assigns.slides_list ++ [nuevo]
      {:noreply, assign(socket, slides_list: slides_list, nueva_imagen_url: "", nueva_imagen_titulo: "", saved: false)}
    else
      {:noreply, socket}
    end
  end

  # Progreso de subida (solo trackear, no consumir aquí)
  @impl true
  def handle_progress(:imagen_carrusel, _entry, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_upload_carrusel", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("cancel_upload_carrusel", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :imagen_carrusel, ref)}
  end

  # Cuando el usuario confirma agregar la imagen al FTP
  @impl true
  def handle_event("subir_imagen", params, socket) do
    entries = socket.assigns.uploads.imagen_carrusel.entries
    if entries == [] do
      {:noreply, assign(socket, upload_error: "Selecciona una imagen primero")}
    else
      titulo = Map.get(params, "titulo", "") |> String.trim()
      socket = assign(socket, uploading: true, upload_error: nil)
      now_ts = System.system_time(:second)

      results =
        consume_uploaded_entries(socket, :imagen_carrusel, fn %{path: tmp_path}, entry ->
          ext     = Path.extname(entry.client_name) |> String.downcase()
          content = File.read!(tmp_path)
          filename = "destacados_#{now_ts}"
          case Sftp.upload_carrusel_destacados_image(filename, ext, content) do
            {:ok, url}       -> {:ok, {:ok, url}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case results do
        [{:ok, url}] ->
          img_count = socket.assigns.slides_list |> Enum.filter(&(&1["kind"] == "imagen")) |> length()
          titulo_final = if titulo == "", do: "Publicidad #{img_count + 1}", else: titulo
          nuevo       = %{"kind" => "imagen", "url" => url, "titulo" => titulo_final}
          slides_list = socket.assigns.slides_list ++ [nuevo]
          # Auto-guardar inmediatamente en la BD para no perder la imagen si el usuario navega
          config_guardado = Map.put(socket.assigns.config, "slides_orden", slides_list)
          seccion = case socket.assigns.seccion && Secciones.update_config(socket.assigns.seccion, config_guardado) do
            {:ok, sec} -> sec
            _ -> socket.assigns.seccion
          end
          {:noreply,
           socket
           |> assign(slides_list: slides_list, seccion: seccion, config: config_guardado,
                     nueva_imagen_titulo: "", uploading: false, upload_error: nil, saved: true)
           |> put_flash(:info, "Imagen subida y guardada correctamente")}
        [{:error, reason}] ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error SFTP: #{inspect(reason)}")}
        _ ->
          {:noreply, assign(socket, uploading: false, upload_error: "Error inesperado al subir")}
      end
    end
  end

  @impl true
  def handle_event("quitar_slide", %{"idx" => idx_str}, socket) do
    idx  = String.to_integer(idx_str)
    list = socket.assigns.slides_list
    slide = Enum.at(list, idx)
    # Si es imagen, borrar del FTP en background
    if slide && slide["kind"] == "imagen" && slide["url"] do
      Task.start(fn -> Sftp.delete_by_url(slide["url"]) end)
    end
    list = List.delete_at(list, idx)
    # Auto-guardar al eliminar para que el cambio persista
    config_guardado = Map.put(socket.assigns.config, "slides_orden", list)
    seccion = case socket.assigns.seccion && Secciones.update_config(socket.assigns.seccion, config_guardado) do
      {:ok, sec} -> sec
      _ -> socket.assigns.seccion
    end
    {:noreply, assign(socket, slides_list: list, seccion: seccion, config: config_guardado, saved: true)}
  end

  # Mantener compatibilidad con el nombre viejo
  def handle_event("quitar_imagen", %{"idx" => idx_str}, socket) do
    handle_event("quitar_slide", %{"idx" => idx_str}, socket)
  end

  # ── Carrusel de Ofertas: reorder slides (secciones + imágenes unificadas) ──

  @impl true
  def handle_event("mover_slide_arriba", %{"idx" => idx_str}, socket) do
    idx  = String.to_integer(idx_str)
    list = socket.assigns.slides_list
    if idx > 0 do
      item = Enum.at(list, idx)
      list = list |> List.delete_at(idx) |> List.insert_at(idx - 1, item)
      {:noreply, socket |> assign(slides_list: list) |> autosave_ofertas()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mover_slide_abajo", %{"idx" => idx_str}, socket) do
    idx  = String.to_integer(idx_str)
    list = socket.assigns.slides_list
    if idx < length(list) - 1 do
      item = Enum.at(list, idx)
      list = list |> List.delete_at(idx) |> List.insert_at(idx + 1, item)
      {:noreply, socket |> assign(slides_list: list) |> autosave_ofertas()}
    else
      {:noreply, socket}
    end
  end

  # Mantener compat con nombres viejos
  def handle_event("mover_promo_arriba", %{"idx" => idx_str}, socket),
    do: handle_event("mover_slide_arriba", %{"idx" => idx_str}, socket)
  def handle_event("mover_promo_abajo", %{"idx" => idx_str}, socket),
    do: handle_event("mover_slide_abajo", %{"idx" => idx_str}, socket)

  # ── Save ──────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", _params, socket) do
    if socket.assigns.seccion do
      config_to_save =
        socket.assigns.config
        |> Map.put("slides_orden", socket.assigns.slides_list)
        |> Map.merge(socket.assigns.promo_configs)
      case Secciones.update_config(socket.assigns.seccion, config_to_save) do
        {:ok, sec} ->
          {:noreply, socket |> assign(seccion: sec, guardando: false, saved: true) |> put_flash(:info, "Sección guardada correctamente")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al guardar")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Render ────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-gray-100">
      <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />
      <section class="flex-1 p-4 sm:p-6 min-w-0 bg-gray-50">
      <header class="mb-6 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-bold text-gray-900"><%= section_title(@tipo) %></h1>
          <p class="text-sm text-gray-500 mt-0.5">Edita el contenido de esta sección</p>
        </div>
        <%= if @saved do %>
          <span class="inline-flex items-center gap-1.5 text-sm font-medium text-green-600">
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
            </svg>
            Guardado
          </span>
        <% end %>
      </header>

      <%= if @seccion == nil do %>
        <div class="flex flex-col items-center justify-center py-24 text-gray-400">
          <svg class="w-10 h-10 mb-3 animate-spin text-purple-400" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
          </svg>
          <p class="text-sm">Cargando...</p>
        </div>
      <% else %>

        <!-- ── PUBLICIDAD ── -->
        <%= if @tipo == "publicidad" do %>
          <%
            c1 = @config["color1"] || "#9333ea"
            c2 = @config["color2"] || "#4f46e5"
            bg_style = "background: linear-gradient(135deg, #{c1}, #{c2});"
          %>
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-6 space-y-5 max-w-lg">
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Título</label>
              <input type="text" value={@config["titulo"] || @seccion.nombre}
                phx-blur="update_pub" phx-value-field="titulo"
                maxlength="100"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Subtítulo</label>
              <input type="text" value={@config["subtitulo"] || "Explora nuestro catálogo completo y encuentra los mejores productos para ti."}
                phx-blur="update_pub" phx-value-field="subtitulo"
                maxlength="200"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Texto del botón</label>
              <input type="text" value={@config["boton"] || "Ver catálogo"}
                phx-blur="update_pub" phx-value-field="boton"
                maxlength="50"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>

            <!-- Color de fondo -->
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-2">Color de fondo</label>
              <!-- Presets -->
              <div class="flex flex-wrap gap-2 mb-3">
                <%= for %{label: label, c1: pc1, c2: pc2} <- @pub_presets do %>
                  <button type="button"
                    phx-click="pub_preset"
                    phx-value-c1={pc1}
                    phx-value-c2={pc2}
                    title={label}
                    style={"width:36px;height:36px;border-radius:50%;background:linear-gradient(135deg,#{pc1},#{pc2});outline:#{if c1 == pc1 and c2 == pc2, do: "3px solid #1f2937", else: "2px solid transparent"};outline-offset:2px;transition:outline 0.15s;"}
                  />
                <% end %>
              </div>
              <!-- Color pickers personalizados -->
              <form phx-change="pub_colors" class="flex items-center gap-3">
                <div class="flex flex-col items-center gap-1">
                  <label class="text-[10px] text-gray-400">Color A</label>
                  <input type="color" name="color1" value={c1}
                    class="w-10 h-10 rounded-lg border border-gray-200 cursor-pointer p-0.5 bg-white" />
                </div>
                <div class="flex flex-col items-center gap-1">
                  <label class="text-[10px] text-gray-400">Color B</label>
                  <input type="color" name="color2" value={c2}
                    class="w-10 h-10 rounded-lg border border-gray-200 cursor-pointer p-0.5 bg-white" />
                </div>
                <div class="flex-1 h-10 rounded-xl shadow-inner" style={bg_style}></div>
              </form>
            </div>

            <!-- Preview -->
            <div>
              <p class="text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wide">Vista previa</p>
              <div class="rounded-2xl p-6 text-white relative overflow-hidden" style={bg_style}>
                <div class="absolute top-0 right-0 w-40 h-40 rounded-full bg-white/5 -translate-y-1/2 translate-x-1/2"></div>
                <h2 class="text-xl font-bold mb-1"><%= @config["titulo"] || @seccion.nombre %></h2>
                <p class="text-white/70 text-xs max-w-xs"><%= @config["subtitulo"] || "Explora nuestro catálogo completo." %></p>
                <span class="mt-4 inline-flex items-center px-4 py-2 bg-white rounded-xl text-xs font-semibold" style={"color:#{c1};"}>
                  <%= @config["boton"] || "Ver catálogo" %>
                </span>
              </div>
            </div>
          </div>
        <% end %>

        <!-- ── ENVÍOS ── -->
        <%= if @tipo == "envios" do %>
          <%
            cards = get_cards(@config)
            colors = ~w(purple green blue orange)
          %>
          <div class="space-y-4 max-w-2xl">
            <%= for {card, idx} <- Enum.with_index(cards) do %>
              <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 flex items-start gap-4">
                <div class={"w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0 #{card_bg(card["color"])}"}>
                  <.card_icon color={card["color"]} />
                </div>
                <div class="flex-1 space-y-2">
                  <div>
                    <label class="block text-[11px] font-semibold text-gray-500 mb-0.5">Título</label>
                    <input type="text" value={card["titulo"]}
                      phx-blur="update_card" phx-value-idx={idx} phx-value-field="titulo"
                      maxlength="50"
                      class="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-semibold text-gray-500 mb-0.5">Descripción</label>
                    <input type="text" value={card["descripcion"]}
                      phx-blur="update_card" phx-value-idx={idx} phx-value-field="descripcion"
                      maxlength="100"
                      class="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- ── CARRUSEL DE OFERTAS (Top 10, Destacados y Favs) ── -->
        <%= if @tipo == "ofertas" do %>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-6 max-w-4xl">

            <!-- 1. Imágenes del carrusel -->
            <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
              <h2 class="font-bold text-gray-900 mb-0.5">Imágenes del carrusel</h2>
              <p class="text-xs text-gray-400 mb-4">...</p>

              <!-- Agregar nueva imagen -->
              <form phx-submit="subir_imagen" phx-change="validate_upload_carrusel" class="border border-dashed border-gray-200 rounded-xl p-4 space-y-3">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Agregar imagen</p>

                <!-- Título -->
                <input type="text" name="titulo" placeholder="Título (opcional)"
                  value={@nueva_imagen_titulo}
                  maxlength="100"
                  class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />

                <!-- Zona de selección -->
                <label class="flex flex-col items-center justify-center w-full h-28 border-2 border-dashed border-purple-300 rounded-xl cursor-pointer bg-purple-50 hover:bg-purple-100 transition-colors">
                  <svg class="w-7 h-7 text-purple-400 mb-1" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5"/>
                  </svg>
                  <span class="text-xs text-purple-500 font-medium">Seleccionar imagen</span>
                  <span class="text-[10px] text-purple-400 mt-0.5">JPG, PNG, WEBP — máx 10MB</span>
                  <.live_file_input upload={@uploads.imagen_carrusel} id="img-input-seccion" phx-hook="ImageCompressor" class="sr-only" />
                </label>

                <!-- Preview + barra de progreso cuando hay archivo seleccionado -->
                <%= for entry <- @uploads.imagen_carrusel.entries do %>
                  <div class="rounded-2xl overflow-hidden bg-gray-100 relative" style="height:140px;">
                    <.live_img_preview entry={entry} class="w-full h-full object-cover" />
                    <div class="absolute top-2 right-2">
                      <button type="button" phx-click="cancel_upload_carrusel" phx-value-ref={entry.ref}
                        class="bg-black/50 hover:bg-black/70 text-white rounded-full w-6 h-6 flex items-center justify-center text-xs">✕</button>
                    </div>
                    <%= if entry.progress < 100 do %>
                      <div class="absolute bottom-0 left-0 right-0 bg-black/50 px-3 py-2">
                        <div class="h-1.5 bg-white/30 rounded-full overflow-hidden">
                          <div class="h-full bg-white rounded-full transition-all" style={"width:#{entry.progress}%"}></div>
                        </div>
                        <p class="text-white text-[10px] font-semibold mt-1">Procesando... <%= entry.progress %>%</p>
                      </div>
                    <% end %>
                  </div>
                  <%= for err <- upload_errors(@uploads.imagen_carrusel, entry) do %>
                    <p class="text-xs text-red-500"><%= error_to_string(err) %></p>
                  <% end %>
                <% end %>

                <!-- Botón submit -->
                <%= if @uploads.imagen_carrusel.entries != [] and hd(@uploads.imagen_carrusel.entries).progress == 100 do %>
                  <button type="submit"
                    disabled={@uploading}
                    class={"w-full flex items-center justify-center gap-2 px-4 py-3 text-white font-semibold text-sm rounded-xl transition-colors #{if @uploading, do: "bg-purple-400 cursor-not-allowed", else: "bg-purple-600 hover:bg-purple-500"}"}>
                    <%= if @uploading do %>
                      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"/>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"/>
                      </svg>
                      Subiendo...
                    <% else %>
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
                      </svg>
                      Subir
                    <% end %>
                  </button>
                <% end %>

                <%= if @upload_error do %>
                  <p class="text-xs text-red-500"><%= @upload_error %></p>
                <% end %>
                <%= for err <- upload_errors(@uploads.imagen_carrusel) do %>
                  <p class="text-xs text-red-500"><%= error_to_string(err) %></p>
                <% end %>
              </form>
            </div>

            <!-- 2. Orden unificado de slides -->
            <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
              <h2 class="font-bold text-gray-900 mb-0.5">Orden del carrusel</h2>
              <p class="text-xs text-gray-400 mb-4">Ordena las secciones e imágenes como quieras que aparezcan en el carrusel.</p>
              <div class="space-y-2">
                <%= for {slide, idx} <- Enum.with_index(@slides_list) do %>
                  <div class="flex items-center gap-3 p-3 bg-gray-50 rounded-xl border border-gray-100">
                    <%= if slide["kind"] == "imagen" do %>
                      <!-- Thumbnail de imagen -->
                      <div class="w-12 h-8 rounded-lg overflow-hidden flex-shrink-0 bg-pink-100">
                        <img src={slide["url"]} class="w-full h-full object-cover" />
                      </div>
                      <span class="w-5 text-center text-xs font-bold text-gray-400"><%= idx + 1 %></span>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-gray-800 truncate"><%= slide["titulo"] || "Publicidad" %></p>
                        <p class="text-[10px] text-pink-500 font-semibold uppercase tracking-wide">Publicidad</p>
                      </div>
                    <% else %>
                      <%
                        ps_cfg   = Map.get(@promo_configs, slide["tipo"], %{})
                        ps_color = ps_cfg["color"] || case slide["tipo"] do
                          "top10"      -> "#c0392b"
                          "favoritos"  -> "#1a5276"
                          "destacados" -> "#1e8449"
                          _            -> "#6c3483"
                        end
                        ps_nombre = ps_cfg["titulo"] || case slide["tipo"] do
                          "top10"      -> "Productos Top 10"
                          "favoritos"  -> "Productos Favoritos"
                          "destacados" -> "Productos Destacados"
                          t            -> t
                        end

                      %>
                      <div class="w-4 h-8 rounded-lg flex-shrink-0" style={"background:#{ps_color};"}></div>
                      <span class="w-5 text-center text-xs font-bold text-gray-400"><%= idx + 1 %></span>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-gray-800 truncate"><%= ps_nombre %></p>
                        <p class="text-[10px] text-gray-400 uppercase tracking-wide"><%= slide["tipo"] %></p>
                      </div>
                    <% end %>
                    <!-- Flechas + quitar -->
                    <div class="flex items-center gap-0.5 flex-shrink-0">
                      <button type="button" phx-click="mover_slide_arriba" phx-value-idx={idx}
                        class={"w-7 h-7 flex items-center justify-center rounded-lg transition-colors #{if idx == 0, do: "text-gray-200 cursor-default", else: "text-gray-400 hover:text-purple-600 hover:bg-purple-50"}"}>
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7"/>
                        </svg>
                      </button>
                      <button type="button" phx-click="mover_slide_abajo" phx-value-idx={idx}
                        class={"w-7 h-7 flex items-center justify-center rounded-lg transition-colors #{if idx == length(@slides_list) - 1, do: "text-gray-200 cursor-default", else: "text-gray-400 hover:text-purple-600 hover:bg-purple-50"}"}>
                        <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                        </svg>
                      </button>
                      <%= if slide["kind"] == "imagen" do %>
                        <button type="button" phx-click="quitar_slide" phx-value-idx={idx}
                          class="ml-1 w-7 h-7 flex items-center justify-center rounded-lg text-gray-300 hover:text-red-500 hover:bg-red-50 transition-colors">
                          <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

          </div>
        <% end %>

        <!-- ── COLOR Y TÍTULO POR SECCIÓN DE OFERTAS ── -->
        <%= if @tipo == "ofertas" do %>
          <%
            tab_tipos = [{"top10", "Top 10"}, {"favoritos", "Favoritos"}, {"destacados", "Destacados"}]
            tab_cfg   = Map.get(@promo_configs, @promo_tab, %{})
            tab_color = tab_cfg["color"] || case @promo_tab do
              "top10"      -> "#c0392b"
              "favoritos"  -> "#1a5276"
              "destacados" -> "#1e8449"
              _            -> "#6c3483"
            end
            tab_titulo = tab_cfg["titulo"] || case @promo_tab do
              "top10"      -> "Top 10"
              "favoritos"  -> "Favoritos"
              "destacados" -> "Destacados"
              t            -> t
            end
          %>
          <p class="text-xs text-gray-400 mb-4">Los productos se seleccionan automáticamente (4 aleatorios por sección según la gama del cliente).</p>
          <!-- Tabs -->
          <div class="flex gap-2 mb-4 mt-2">
            <%= for {t, label} <- tab_tipos do %>
              <button type="button" phx-click="set_promo_tab" phx-value-tipo={t}
                class={"px-4 py-1.5 rounded-full text-sm font-semibold transition-all #{if @promo_tab == t, do: "bg-purple-600 text-white shadow", else: "bg-white border border-gray-200 text-gray-600 hover:border-purple-400"}"}>
                <%= label %>
              </button>
            <% end %>
          </div>
          <!-- Config color/título del tab activo -->
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 max-w-lg space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Título</label>
              <input type="text" value={tab_titulo}
                phx-blur="update_pub" phx-value-field="titulo"
                maxlength="100"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-2">Color de fondo</label>
              <div class="flex flex-wrap gap-2 mb-3">
                <%= for %{label: label, c1: pc1, c2: _} <- @pub_presets do %>
                  <button type="button" phx-click="sec_color" phx-value-color={pc1} title={label}
                    style={"width:32px;height:32px;border-radius:50%;background:#{pc1};outline:#{if tab_color == pc1, do: "3px solid #1f2937", else: "2px solid transparent"};outline-offset:2px;"} />
                <% end %>
              </div>
              <form phx-change="sec_color_custom" class="flex items-center gap-3">
                <input type="color" name="color" value={tab_color}
                  class="w-10 h-10 rounded-lg border border-gray-200 cursor-pointer p-0.5 bg-white" />
                <div class="flex-1 h-10 rounded-xl shadow-inner" style={"background:#{tab_color};"}></div>
                <span class="text-xs font-mono text-gray-400"><%= tab_color %></span>
              </form>
            </div>
          </div>
        <% end %>

      <% end %>
    </section>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp section_title("ofertas"),    do: "Carrusel de Ofertas"
  defp section_title("publicidad"), do: "Publicidad"
  defp section_title("envios"),     do: "Envíos"
  defp section_title(t),            do: t

  defp get_codigos(%{"codigos" => c}) when is_list(c), do: c
  defp get_codigos(_), do: []

  defp error_to_string(:too_large),        do: "Archivo demasiado grande (máx 10 MB)"
  defp error_to_string(:not_accepted),     do: "Tipo de archivo no permitido (usa JPG, PNG, GIF o WebP)"
  defp error_to_string(:too_many_files),   do: "Solo se permite 1 imagen a la vez"
  defp error_to_string(_),                 do: "Error al subir el archivo"

  defp autosave_ofertas(socket) do
    if socket.assigns.seccion do
      config_to_save =
        socket.assigns.config
        |> Map.put("slides_orden", socket.assigns.slides_list)
        |> Map.merge(socket.assigns.promo_configs)
      case Secciones.update_config(socket.assigns.seccion, config_to_save) do
        {:ok, sec} -> assign(socket, seccion: sec, saved: true)
        _          -> assign(socket, saved: false)
      end
    else
      socket
    end
  end

  defp autosave(socket) do
    if socket.assigns.seccion do
      case Secciones.update_config(socket.assigns.seccion, socket.assigns.config) do
        {:ok, sec} -> assign(socket, seccion: sec, saved: true)
        _          -> assign(socket, saved: false)
      end
    else
      socket
    end
  end

  defp get_cards(%{"cards" => c}) when is_list(c) and length(c) == 4, do: c
  defp get_cards(_), do: @default_cards

  defp card_bg("purple"), do: "bg-purple-100"
  defp card_bg("green"),  do: "bg-green-100"
  defp card_bg("blue"),   do: "bg-blue-100"
  defp card_bg("orange"), do: "bg-orange-100"
  defp card_bg(_),        do: "bg-gray-100"

  attr :color, :string, required: true
  defp card_icon(assigns) do
    ~H"""
    <%= case @color do %>
      <% "purple" -> %>
        <svg class="w-5 h-5 text-purple-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h1m8-1a1 1 0 01-1 1H9m4-1V8a1 1 0 011-1h2.586a1 1 0 01.707.293l3.414 3.414a1 1 0 01.293.707V16a1 1 0 01-1 1h-1m-6-1a1 1 0 001 1h1M5 17a2 2 0 104 0m-4 0a2 2 0 114 0m6 0a2 2 0 104 0m-4 0a2 2 0 114 0"/>
        </svg>
      <% "green" -> %>
        <svg class="w-5 h-5 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
        </svg>
      <% "blue" -> %>
        <svg class="w-5 h-5 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
      <% "orange" -> %>
        <svg class="w-5 h-5 text-orange-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 5.636l-3.536 3.536m0 5.656l3.536 3.536M9.172 9.172L5.636 5.636m3.536 9.192l-3.536 3.536M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-5 0a4 4 0 11-8 0 4 4 0 018 0z"/>
        </svg>
      <% _ -> %>
        <svg class="w-5 h-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
          <circle cx="12" cy="12" r="8"/>
        </svg>
    <% end %>
    """
  end
end
