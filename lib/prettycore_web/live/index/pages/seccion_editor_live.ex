defmodule PrettycoreWeb.SeccionEditorLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Secciones
  alias Prettycore.Productos

  @default_cards [
    %{"titulo" => "Envío rápido",  "descripcion" => "Entrega en 24-48h",         "color" => "purple"},
    %{"titulo" => "Compra segura", "descripcion" => "Protección garantizada",    "color" => "green"},
    %{"titulo" => "Devoluciones",  "descripcion" => "30 días sin preguntas",     "color" => "blue"},
    %{"titulo" => "Soporte 24/7",  "descripcion" => "Siempre disponible",        "color" => "orange"},
  ]

  @impl true
  def mount(%{"tipo" => tipo}, _session, socket) do
    socket =
      socket
      |> assign(:current_page, "seccion_#{tipo}")
      |> assign(:sidebar_open, true)
      |> assign(:show_programacion_children, false)
      |> assign(:tipo, tipo)
      |> assign(:seccion, nil)
      |> assign(:config, %{})
      |> assign(:productos, [])
      |> assign(:search, "")
      |> assign(:guardando, false)
      |> assign(:saved, false)

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
        do: Productos.list_productos(),
        else: []

    {:noreply, assign(socket, seccion: seccion, config: config, productos: productos)}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    dest =
      case id do
        "toggle_sidebar"    -> nil
        "inicio"            -> ~p"/admin/platform"
        "clientes"          -> ~p"/admin/clientes"
        "tienda"            -> ~p"/admin/tienda"
        "pedidos"           -> ~p"/admin/pedidos"
        "categorias"        -> ~p"/admin/categorias"
        "super_categorias"  -> ~p"/admin/super-categorias"
        "carrusel"          -> ~p"/admin/carrusel"
        "secciones"         -> ~p"/admin/secciones"
        "usuarios"          -> ~p"/admin/usuarios"
        "seccion_top10"     -> ~p"/admin/seccion/top10"
        "seccion_favoritos" -> ~p"/admin/seccion/favoritos"
        "seccion_destacados"-> ~p"/admin/seccion/destacados"
        "seccion_publicidad"-> ~p"/admin/seccion/publicidad"
        "seccion_envios"    -> ~p"/admin/seccion/envios"
        _                   -> nil
      end

    if id == "toggle_sidebar" do
      {:noreply, update(socket, :sidebar_open, &(not &1))}
    else
      if dest, do: {:noreply, push_navigate(socket, to: dest)}, else: {:noreply, socket}
    end
  end

  # ── Productos section: toggle individual product ──────────────────────

  @impl true
  def handle_event("toggle_producto", %{"codigo" => codigo}, socket) do
    codigos = get_codigos(socket.assigns.config)
    codigos = if codigo in codigos, do: List.delete(codigos, codigo), else: codigos ++ [codigo]
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, "codigos", codigos), saved: false)}
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

  # ── Envios section ────────────────────────────────────────────────────

  @impl true
  def handle_event("update_card", %{"idx" => idx_str, "field" => field, "value" => value}, socket) do
    idx   = String.to_integer(idx_str)
    cards = get_cards(socket.assigns.config)
    card  = cards |> Enum.at(idx) |> Map.put(field, value)
    cards = List.replace_at(cards, idx, card)
    {:noreply, assign(socket, config: Map.put(socket.assigns.config, "cards", cards), saved: false)}
  end

  # ── Save ──────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", _params, socket) do
    if socket.assigns.seccion do
      case Secciones.update_config(socket.assigns.seccion, socket.assigns.config) do
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
    <section class="p-4 sm:p-6 min-h-screen bg-gray-50">
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
            <!-- Preview -->
            <div>
              <p class="text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wide">Vista previa</p>
              <div class="rounded-2xl bg-gradient-to-r from-purple-600 via-violet-600 to-indigo-600 p-6 text-white relative overflow-hidden">
                <div class="absolute top-0 right-0 w-40 h-40 rounded-full bg-white/5 -translate-y-1/2 translate-x-1/2"></div>
                <h2 class="text-xl font-bold mb-1"><%= @config["titulo"] || @seccion.nombre %></h2>
                <p class="text-purple-200 text-xs max-w-xs"><%= @config["subtitulo"] || "Explora nuestro catálogo completo." %></p>
                <span class="mt-4 inline-flex items-center px-4 py-2 bg-white text-purple-700 rounded-xl text-xs font-semibold">
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

        <!-- ── SECCIONES DE PRODUCTOS (top10 / favoritos / destacados) ── -->
        <%= if @tipo in ["top10", "favoritos", "destacados"] do %>
          <%
            codigos = get_codigos(@config)
            filtered =
              if @search != "",
                do: Enum.filter(@productos, fn p ->
                  s = String.downcase(@search)
                  String.contains?(String.downcase(p.descripcion || ""), s) or
                  String.contains?(String.downcase(p.codigo || ""), s)
                end),
                else: @productos
          %>
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
            <span class="text-sm text-gray-500 font-medium flex-shrink-0">
              <%= length(codigos) %> seleccionados
            </span>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 xl:grid-cols-6 gap-3 max-h-[70vh] overflow-y-auto pr-1">
            <%= for prod <- filtered do %>
              <%
                seleccionado = prod.codigo in codigos
              %>
              <button
                type="button"
                phx-click="toggle_producto"
                phx-value-codigo={prod.codigo}
                class={"relative bg-white rounded-xl overflow-hidden border-2 transition-all #{if seleccionado, do: "border-purple-500 shadow-md", else: "border-gray-100 hover:border-gray-300"}"}
              >
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
    """
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  defp section_title("top10"),      do: "Productos Top 10"
  defp section_title("favoritos"),  do: "Productos Favoritos"
  defp section_title("destacados"), do: "Productos Destacados"
  defp section_title("publicidad"), do: "Publicidad"
  defp section_title("envios"),     do: "Envíos"
  defp section_title(t),            do: t

  defp get_codigos(%{"codigos" => c}) when is_list(c), do: c
  defp get_codigos(_), do: []

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
