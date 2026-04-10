defmodule PrettycoreWeb.SeccionEditorLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Secciones
  alias Prettycore.ProductosNativos

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
    seccion = Secciones.get_seccion_by_tipo(tipo)
    config  = (seccion && seccion.config) || %{}

    productos =
      if tipo in ["top10", "favoritos", "destacados"],
        do: ProductosNativos.list_todos(),
        else: []

    {promo_secciones, promo_configs, slides_list} =
      if tipo == "destacados" do
        secs =
          ~w(top10 favoritos destacados)
          |> Enum.map(&Secciones.get_seccion_by_tipo/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(& &1.orden)
        configs = Map.new(secs, fn s -> {s.tipo, s.config || %{}} end)

        slides =
          case config["slides_orden"] do
            list when is_list(list) and list != [] -> list
            _ ->
              # Fallback: secciones en orden DB + imágenes del formato viejo al final
              promo_slides = Enum.map(secs, &%{"kind" => "seccion", "tipo" => &1.tipo})
              img_slides   = Enum.map(config["imagen_slides"] || [], &Map.put(&1, "kind", "imagen"))
              promo_slides ++ img_slides
          end

        {secs, configs, slides}
      else
        {[], %{}, []}
      end

    {:noreply, assign(socket,
      seccion: seccion,
      config: config,
      productos: productos,
      promo_secciones: promo_secciones,
      promo_configs: promo_configs,
      slides_list: slides_list
    )}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    case id do
      "toggle_sidebar"             -> {:noreply, update(socket, :sidebar_open, &(not &1))}
      "clientes"                   -> {:noreply, update(socket, :show_clientes_children, &(not &1))}
      "clientes_frog"              -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}
      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "inicio"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/platform")}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "tienda"                     -> {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}
      "pedidos"                    -> {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}
      "categorias"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}
      "super_categorias"           -> {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}
      "carrusel"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}
      "secciones"                  -> {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}
      "usuarios"                   -> {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}
      _                            -> {:noreply, socket}
    end
  end

  # ── Productos section: toggle individual product ──────────────────────

  @impl true
  def handle_event("set_promo_tab", %{"tipo" => tipo}, socket) do
    {:noreply, assign(socket, promo_tab: tipo, search: "")}
  end

  @impl true
  def handle_event("toggle_producto", %{"codigo" => codigo}, socket) do
    if socket.assigns.tipo == "destacados" do
      # Operar sobre promo_configs[promo_tab]
      tab    = socket.assigns.promo_tab
      cfg    = Map.get(socket.assigns.promo_configs, tab, %{})
      codigos = get_codigos(cfg)
      codigos = if codigo in codigos, do: List.delete(codigos, codigo), else: codigos ++ [codigo]
      cfg    = Map.put(cfg, "codigos", codigos)
      promo_configs = Map.put(socket.assigns.promo_configs, tab, cfg)
      # Si es la tab de destacados, sincronizar @config (que también guarda imagen_slides)
      config = if tab == "destacados",
        do: Map.merge(socket.assigns.config, %{"codigos" => codigos}),
        else: socket.assigns.config
      {:noreply, assign(socket, promo_configs: promo_configs, config: config, saved: false)}
    else
      codigos = get_codigos(socket.assigns.config)
      codigos = if codigo in codigos, do: List.delete(codigos, codigo), else: codigos ++ [codigo]
      {:noreply, assign(socket, config: Map.put(socket.assigns.config, "codigos", codigos), saved: false)}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, search: q)}
  end

  # ── Publicidad section ────────────────────────────────────────────────

  @impl true
  def handle_event("update_pub", %{"field" => field, "value" => value}, socket) do
    config = Map.put(socket.assigns.config, field, value)
    {:noreply, assign(socket, config: config, saved: false)}
  end

  @impl true
  def handle_event("sec_color", %{"color" => color}, socket) do
    config = Map.put(socket.assigns.config, "color", color)
    {:noreply, assign(socket, config: config, saved: false)}
  end

  @impl true
  def handle_event("sec_color_custom", %{"color" => color}, socket) do
    config = Map.put(socket.assigns.config, "color", color)
    {:noreply, assign(socket, config: config, saved: false)}
  end

  @impl true
  def handle_event("pub_preset", %{"c1" => c1, "c2" => c2}, socket) do
    config = socket.assigns.config |> Map.put("color1", c1) |> Map.put("color2", c2)
    {:noreply, assign(socket, config: config, saved: false)}
  end

  @impl true
  def handle_event("pub_colors", %{"color1" => c1, "color2" => c2}, socket) do
    config = socket.assigns.config |> Map.put("color1", c1) |> Map.put("color2", c2)
    {:noreply, assign(socket, config: config, saved: false)}
  end

  # ── Envios section ────────────────────────────────────────────────────

  @impl true
  def handle_event("update_card", %{"idx" => idx_str, "field" => field, "value" => value}, socket) do
    idx   = String.to_integer(idx_str)
    cards = get_cards(socket.assigns.config)
    card  = cards |> Enum.at(idx) |> Map.put(field, value)
    cards = List.replace_at(cards, idx, card)
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, "cards", cards), saved: false)}
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

  # Cuando el usuario confirma agregar la imagen ya subida
  @impl true
  def handle_event("subir_imagen", _params, socket) do
    titulo = socket.assigns.nueva_imagen_titulo
    uploaded_urls =
      consume_uploaded_entries(socket, :imagen_carrusel, fn %{path: path}, ent ->
        ext      = Path.extname(ent.client_name)
        filename = "#{System.unique_integer([:positive])}#{ext}"
        priv_dir = Application.app_dir(:prettycore, "priv")
        dest     = Path.join([priv_dir, "static", "uploads", "carrusel", filename])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)
        {:ok, "/uploads/carrusel/#{filename}"}
      end)
    case uploaded_urls do
      [url | _] ->
        nuevo       = %{"kind" => "imagen", "url" => url, "titulo" => String.trim(titulo)}
        slides_list = socket.assigns.slides_list ++ [nuevo]
        {:noreply, assign(socket, slides_list: slides_list, nueva_imagen_titulo: "", saved: false)}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("quitar_slide", %{"idx" => idx_str}, socket) do
    idx  = String.to_integer(idx_str)
    list = List.delete_at(socket.assigns.slides_list, idx)
    {:noreply, assign(socket, slides_list: list, saved: false)}
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
      {:noreply, assign(socket, slides_list: list, saved: false)}
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
      {:noreply, assign(socket, slides_list: list, saved: false)}
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
      # Si es el editor del Carrusel de Ofertas
      if socket.assigns.tipo == "destacados" do
        # Extraer el orden de secciones promo del slides_list para reordenar en DB
        promo_tipos = ~w(top10 favoritos destacados)
        promo_ids =
          socket.assigns.slides_list
          |> Enum.filter(&(&1["kind"] == "seccion" and &1["tipo"] in promo_tipos))
          |> Enum.map(fn s ->
            sec = Enum.find(socket.assigns.promo_secciones, &(&1.tipo == s["tipo"]))
            sec && sec.id
          end)
          |> Enum.reject(&is_nil/1)
        if promo_ids != [], do: Secciones.reorder(promo_ids)
        # Guardar configs de top10 y favoritos
        Enum.each(["top10", "favoritos"], fn t ->
          sec = Secciones.get_seccion_by_tipo(t)
          cfg = Map.get(socket.assigns.promo_configs, t, %{})
          if sec, do: Secciones.update_config(sec, cfg)
        end)
      end
      # Guardar slides_orden en el config de esta sección
      config_to_save = Map.put(socket.assigns.config, "slides_orden", socket.assigns.slides_list)
      case Secciones.update_config(socket.assigns.seccion, config_to_save) do
        {:ok, sec} ->
          {:noreply, assign(socket, seccion: sec, guardando: false, saved: true)}
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
        <button
          phx-click="guardar"
          class={"inline-flex items-center gap-2 px-5 py-2 rounded-xl text-sm font-semibold transition-all #{if @saved, do: "bg-green-500 text-white", else: "bg-purple-600 text-white hover:bg-purple-500"}"}
        >
          <%= if @saved do %>
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
            </svg>
            Guardado
          <% else %>
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"/>
            </svg>
            Guardar cambios
          <% end %>
        </button>
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
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Subtítulo</label>
              <input type="text" value={@config["subtitulo"] || "Explora nuestro catálogo completo y encuentra los mejores productos para ti."}
                phx-blur="update_pub" phx-value-field="subtitulo"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Texto del botón</label>
              <input type="text" value={@config["boton"] || "Ver catálogo"}
                phx-blur="update_pub" phx-value-field="boton"
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
                      class="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                  </div>
                  <div>
                    <label class="block text-[11px] font-semibold text-gray-500 mb-0.5">Descripción</label>
                    <input type="text" value={card["descripcion"]}
                      phx-blur="update_card" phx-value-idx={idx} phx-value-field="descripcion"
                      class="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- ── CARRUSEL DE OFERTAS (destacados = editor maestro) ── -->
        <%= if @tipo == "destacados" do %>
          <div class="space-y-6 max-w-2xl">

            <!-- 1. Imágenes del carrusel -->
            <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
              <h2 class="font-bold text-gray-900 mb-0.5">Imágenes del carrusel</h2>
              <p class="text-xs text-gray-400 mb-4">Sube tu imagen al FTP y pega la URL aquí. Aparecerán como slides antes de las secciones de productos.</p>

              <!-- Agregar nueva imagen -->
              <div class="border border-dashed border-gray-200 rounded-xl p-4 space-y-3">
                <p class="text-[11px] font-semibold text-gray-500 uppercase tracking-wide">Agregar imagen</p>

                <!-- Título -->
                <input type="text" placeholder="Título (opcional)"
                  value={@nueva_imagen_titulo}
                  phx-blur="update_nueva_imagen"
                  class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />

                <!-- Preview + barra de progreso cuando hay archivo seleccionado -->
                <%= for entry <- @uploads.imagen_carrusel.entries do %>
                  <div class="rounded-2xl overflow-hidden bg-gray-100 relative" style="height:160px;">
                    <.live_img_preview entry={entry} class="w-full h-full object-cover" />
                    <%= if entry.progress < 100 do %>
                      <div class="absolute bottom-0 left-0 right-0 bg-black/50 px-3 py-2">
                        <div class="h-1.5 bg-white/30 rounded-full overflow-hidden">
                          <div class="h-full bg-white rounded-full transition-all" style={"width:#{entry.progress}%"}></div>
                        </div>
                        <p class="text-white text-[10px] font-semibold mt-1">Transfiriendo... <%= entry.progress %>%</p>
                      </div>
                    <% end %>
                  </div>
                  <%= for err <- upload_errors(@uploads.imagen_carrusel, entry) do %>
                    <p class="text-xs text-red-500"><%= error_to_string(err) %></p>
                  <% end %>
                <% end %>

                <!-- Botones -->
                <div class="flex gap-2">
                  <label class="flex-1 flex items-center justify-center gap-2 cursor-pointer px-4 py-3 bg-gray-100 hover:bg-gray-200 text-gray-700 font-semibold text-sm rounded-xl transition-colors">
                    <svg class="w-4 h-4 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"/>
                    </svg>
                    Seleccionar imagen
                    <.live_file_input upload={@uploads.imagen_carrusel} id="img-input-seccion" phx-hook="ImageCompressor" class="hidden" />
                  </label>
                  <%= if @uploads.imagen_carrusel.entries != [] and hd(@uploads.imagen_carrusel.entries).progress == 100 do %>
                    <button type="button" phx-click="subir_imagen"
                      class="flex-1 flex items-center justify-center gap-2 px-4 py-3 bg-purple-600 hover:bg-purple-500 text-white font-semibold text-sm rounded-xl transition-colors">
                      <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                      </svg>
                      Agregar imagen
                    </button>
                  <% end %>
                </div>
                <%= for err <- upload_errors(@uploads.imagen_carrusel) do %>
                  <p class="text-xs text-red-500"><%= error_to_string(err) %></p>
                <% end %>
              </div>
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
                      <div class="w-12 h-8 rounded-lg overflow-hidden flex-shrink-0 bg-gray-200">
                        <img src={slide["url"]} class="w-full h-full object-cover" />
                      </div>
                      <span class="w-5 text-center text-xs font-bold text-gray-400"><%= idx + 1 %></span>
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-semibold text-gray-800 truncate"><%= slide["titulo"] || "(imagen)" %></p>
                        <p class="text-[10px] text-purple-500 font-semibold uppercase tracking-wide">Imagen</p>
                      </div>
                    <% else %>
                      <%
                        ps = Enum.find(@promo_secciones, &(&1.tipo == slide["tipo"])) || %{config: %{}, nombre: slide["tipo"], tipo: slide["tipo"]}
                        ps_cfg   = (is_map(ps) and Map.has_key?(ps, :config) and ps.config) || %{}
                        ps_color = ps_cfg["color"] || case slide["tipo"] do
                          "top10"      -> "#c0392b"
                          "favoritos"  -> "#1a5276"
                          "destacados" -> "#1e8449"
                          _            -> "#6c3483"
                        end
                        ps_nombre = ps_cfg["titulo"] || (is_map(ps) and Map.has_key?(ps, :nombre) and ps.nombre) || slide["tipo"]
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

            <!-- 3. Selección de productos por sección -->
            <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5">
              <h2 class="font-bold text-gray-900 mb-3">Productos por sección</h2>
              <!-- Tabs -->
              <div class="flex gap-1 mb-4 bg-gray-100 p-1 rounded-xl">
                <%= for ps <- @promo_secciones do %>
                  <%
                    ps_color = (ps.config || %{})["color"] || case ps.tipo do
                      "top10"      -> "#c0392b"
                      "favoritos"  -> "#1a5276"
                      "destacados" -> "#1e8449"
                      _            -> "#6c3483"
                    end
                    ps_label = (ps.config || %{})["titulo"] || ps.nombre
                    ps_count = length(get_codigos(Map.get(@promo_configs, ps.tipo, %{})))
                  %>
                  <button type="button" phx-click="set_promo_tab" phx-value-tipo={ps.tipo}
                    class={"flex-1 flex items-center justify-center gap-1.5 px-3 py-2 rounded-lg text-xs font-semibold transition-all #{if @promo_tab == ps.tipo, do: "bg-white shadow text-gray-900", else: "text-gray-500 hover:text-gray-700"}"}>
                    <span class="w-2 h-2 rounded-full flex-shrink-0" style={"background:#{ps_color};"}></span>
                    <span class="truncate"><%= ps_label %></span>
                    <span class={"text-[10px] font-bold px-1 py-0.5 rounded #{if @promo_tab == ps.tipo, do: "bg-purple-100 text-purple-700", else: "bg-gray-200 text-gray-500"}"}><%= ps_count %></span>
                  </button>
                <% end %>
              </div>
              <%
                codigos  = get_codigos(Map.get(@promo_configs, @promo_tab, %{}))
                filtered =
                  if @search != "",
                    do: Enum.filter(@productos, fn p ->
                      s = String.downcase(@search)
                      String.contains?(String.downcase(p.descripcion || ""), s) or
                      String.contains?(String.downcase(p.codigo || ""), s)
                    end),
                    else: @productos
              %>
              <div class="mb-3 flex items-center gap-3">
                <div class="flex-1 relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                    </svg>
                  </div>
                  <input type="text" phx-keyup="search" name="q" value={@search}
                    placeholder="Buscar producto..."
                    class="block w-full pl-9 pr-4 py-2 bg-white border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none shadow-sm" />
                </div>
                <span class="text-sm text-gray-500 font-medium flex-shrink-0"><%= length(codigos) %> seleccionados</span>
              </div>
              <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 max-h-[60vh] overflow-y-auto pr-1">
                <%= for prod <- filtered do %>
                  <% seleccionado = prod.codigo in codigos %>
                  <button type="button" phx-click="toggle_producto" phx-value-codigo={prod.codigo}
                    class={"relative bg-white rounded-xl overflow-hidden border-2 transition-all #{if seleccionado, do: "border-purple-500 shadow-md", else: "border-gray-100 hover:border-gray-300"}"}>
                    <div class="aspect-square bg-gray-50 overflow-hidden">
                      <%= if prod.imagen_url && prod.imagen_url != "" do %>
                        <img src={prod.imagen_url} alt={prod.descripcion} class="w-full h-full object-cover" />
                      <% else %>
                        <div class="w-full h-full flex items-center justify-center">
                          <svg class="w-8 h-8 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                          </svg>
                        </div>
                      <% end %>
                    </div>
                    <div class="p-2 text-left">
                      <p class="text-[10px] font-semibold text-gray-800 line-clamp-2 leading-tight"><%= prod.descripcion %></p>
                      <p class="text-[9px] text-gray-400 font-mono mt-0.5"><%= prod.codigo %></p>
                    </div>
                    <%= if seleccionado do %>
                      <div class="absolute top-1.5 right-1.5 w-5 h-5 bg-purple-600 rounded-full flex items-center justify-center">
                        <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                        </svg>
                      </div>
                    <% end %>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>

        <!-- ── SECCIONES DE PRODUCTOS individuales (top10 / favoritos) ── -->
        <%= if @tipo in ["top10", "favoritos"] do %>
          <%
            codigos = get_codigos(@config)
            sec_color = @config["color"] || case @tipo do
              "top10"      -> "#c0392b"
              "favoritos"  -> "#1a5276"
              _            -> "#6c3483"
            end
            sec_titulo = @config["titulo"] || @seccion.nombre
            filtered =
              if @search != "",
                do: Enum.filter(@productos, fn p ->
                  s = String.downcase(@search)
                  String.contains?(String.downcase(p.descripcion || ""), s) or
                  String.contains?(String.downcase(p.codigo || ""), s)
                end),
                else: @productos
          %>
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm p-5 mb-5 max-w-lg space-y-4">
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-1">Título de la sección</label>
              <input type="text" value={sec_titulo}
                phx-blur="update_pub" phx-value-field="titulo"
                class="w-full px-3 py-2 border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-600 mb-2">Color de fondo</label>
              <div class="flex flex-wrap gap-2 mb-3">
                <%= for %{label: label, c1: pc1, c2: _} <- @pub_presets do %>
                  <button type="button" phx-click="sec_color" phx-value-color={pc1} title={label}
                    style={"width:32px;height:32px;border-radius:50%;background:#{pc1};outline:#{if sec_color == pc1, do: "3px solid #1f2937", else: "2px solid transparent"};outline-offset:2px;"} />
                <% end %>
              </div>
              <form phx-change="sec_color_custom" class="flex items-center gap-3">
                <input type="color" name="color" value={sec_color}
                  class="w-10 h-10 rounded-lg border border-gray-200 cursor-pointer p-0.5 bg-white" />
                <div class="flex-1 h-10 rounded-xl shadow-inner" style={"background:#{sec_color};"}></div>
                <span class="text-xs font-mono text-gray-400"><%= sec_color %></span>
              </form>
            </div>
          </div>
          <div class="mb-4 flex items-center gap-3 max-w-xl">
            <div class="flex-1 relative">
              <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <svg class="h-4 w-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
              </div>
              <input type="text" phx-keyup="search" name="q" value={@search}
                placeholder="Buscar producto..."
                class="block w-full pl-9 pr-4 py-2 bg-white border border-gray-200 rounded-xl text-sm focus:ring-2 focus:ring-purple-500 focus:outline-none shadow-sm" />
            </div>
            <span class="text-sm text-gray-500 font-medium flex-shrink-0"><%= length(codigos) %> seleccionados</span>
          </div>
          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3 max-h-[70vh] overflow-y-auto pr-1">
            <%= for prod <- filtered do %>
              <% seleccionado = prod.codigo in codigos %>
              <button type="button" phx-click="toggle_producto" phx-value-codigo={prod.codigo}
                class={"relative bg-white rounded-xl overflow-hidden border-2 transition-all #{if seleccionado, do: "border-purple-500 shadow-md", else: "border-gray-100 hover:border-gray-300"}"}>
                <div class="aspect-square bg-gray-50 overflow-hidden">
                  <%= if prod.imagen_url && prod.imagen_url != "" do %>
                    <img src={prod.imagen_url} alt={prod.descripcion} class="w-full h-full object-cover" />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center">
                      <svg class="w-8 h-8 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                    </div>
                  <% end %>
                </div>
                <div class="p-2 text-left">
                  <p class="text-[10px] font-semibold text-gray-800 line-clamp-2 leading-tight"><%= prod.descripcion %></p>
                  <p class="text-[9px] text-gray-400 font-mono mt-0.5"><%= prod.codigo %></p>
                </div>
                <%= if seleccionado do %>
                  <div class="absolute top-1.5 right-1.5 w-5 h-5 bg-purple-600 rounded-full flex items-center justify-center">
                    <svg class="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </button>
            <% end %>
          </div>
        <% end %>

      <% end %>
    </section>
    </div>
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp section_title("top10"),      do: "Productos Top 10"
  defp section_title("favoritos"),  do: "Productos Favoritos"
  defp section_title("destacados"), do: "Carrusel de Ofertas"
  defp section_title("publicidad"), do: "Publicidad"
  defp section_title("envios"),     do: "Envíos"
  defp section_title(t),            do: t

  defp get_codigos(%{"codigos" => c}) when is_list(c), do: c
  defp get_codigos(_), do: []

  defp error_to_string(:too_large),        do: "Archivo demasiado grande (máx 10 MB)"
  defp error_to_string(:not_accepted),     do: "Tipo de archivo no permitido (usa JPG, PNG, GIF o WebP)"
  defp error_to_string(:too_many_files),   do: "Solo se permite 1 imagen a la vez"
  defp error_to_string(_),                 do: "Error al subir el archivo"

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
