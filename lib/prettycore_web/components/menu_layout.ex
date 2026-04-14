defmodule PrettycoreWeb.MenuLayout do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @menu [
    %{id: "inicio", label: "Inicio"},
  #  %{id: "programacion", label: "Programación"},
  #  %{id: "workorder", label: "Orden T"},
    %{id: "clientes", label: "Clientes"},
    %{id: "tienda", label: "Tienda"},
    %{id: "pedidos", label: "Pedidos"},
    %{id: "usuarios", label: "Usuarios", admin_only: true}
  ]

  # Props y slot
  attr :current_page, :string, required: true
  attr :menu_event, :string, default: "change_page"
  attr :show_programacion_children, :boolean, default: false
  attr :show_clientes_children, :boolean, default: false
  attr :show_prettycore_children, :boolean, default: false
  attr :sidebar_open, :boolean, default: false
  attr :current_user_email, :string, default: nil
  attr :current_user_name, :string, default: nil
  attr :company_logo, :string, default: nil
  attr :user_role, :string, default: nil
  attr :user_permissions, :list, default: nil
  attr :modo_nativo, :boolean, default: false
  slot :inner_block, required: true

  def sidebar(assigns) do
    assigns = assign(assigns, :menu_items, filter_menu(@menu, assigns.user_permissions, assigns.user_role, assigns.modo_nativo))

    ~H"""
    <div class="pc-platform">
      <!-- Barra negra superior full-width con branding PRETTYCORE -->
      <div class="pc-topbar">
        <!-- Hamburger: solo visible en móvil, dentro de la topbar -->
        <button
          type="button"
          class="pc-mobile-menu-btn"
          phx-click={mobile_toggle_js()}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
        <img
          src="https://prettycore.xyz/IMAGENES/PRETTYCORE_NEGRO.png"
          alt="PRETTYCORE"
          class="pc-topbar-logo"
        />
      </div>
      <!-- Fila: Sidebar + Contenido -->
      <div class="pc-platform-row">
        <!-- Mobile overlay -->
        <div
          class="pc-sidebar-overlay"
          phx-click={mobile_toggle_js()}
        />
        <!-- Sidebar -->
        <aside class={"pc-platform-sidebar" <> if @sidebar_open, do: " pc-platform-sidebar-open", else: ""}>
          <!-- HEADER: Logo gota + toggle -->
          <div class="pc-sidebar-header">
            <div class="pc-sidebar-brand">
              <img
                src="https://prettycore.xyz/IMAGENES/Logo%20Prettycore%20(8).png"
                alt="PrettyCore"
                class="pc-sidebar-drop-logo"
              />
            </div>
          <button
            type="button"
            class="pc-sidebar-toggle"
            phx-click={toggle_sidebar_js(@menu_event)}
          >
            <%= if @sidebar_open do %>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="11 17 6 12 11 7" /><polyline points="18 17 13 12 18 7" />
              </svg>
            <% else %>
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="13 17 18 12 13 7" /><polyline points="6 17 11 12 6 7" />
              </svg>
            <% end %>
          </button>
        </div>

        <!-- CUERPO DEL MENÚ -->
        <div class="pc-sidebar-body">
          <div>
            <!-- SECCIÓN: MENÚ -->
            <div class="pc-sidebar-section-label">Menú</div>
            <nav class="pc-sidebar-nav">
              <%= for item <- @menu_items do %>
                <button
                  type="button"
                  class={menu_item_class(menu_active?(item.id, @current_page))}
                  phx-click={@menu_event}
                  phx-value-id={item.id}
                >
                  <span class="pc-nav-icon"><.pc_icon name={item.id} /></span>
                  <span class="pc-nav-label">{item.label}</span>
                </button>
                <%= if item.id == "programacion" and @show_programacion_children do %>
                  <div class="pc-submenu">
                    <button
                      type="button"
                      class={submenu_item_class("programacion_sql", @current_page)}
                      phx-click={@menu_event}
                      phx-value-id="programacion_sql"
                    >
                      <span class="pc-submenu-dot" />
                      <span class="pc-nav-label">Herramienta SQL</span>
                    </button>
                  </div>
                <% end %>
                <%= if item.id == "clientes" and @show_clientes_children and (@user_role == "sysadmin" or "clientes" in (@user_permissions || [])) do %>
                  <div class="pc-submenu">
                    <button
                      type="button"
                      class={submenu_item_class("clientes", @current_page)}
                      phx-click={@menu_event}
                      phx-value-id="clientes_frog"
                    >
                      <span class="pc-submenu-dot" />
                      <span class="pc-nav-label">Clientes Frog</span>
                    </button>
                  </div>
                <% end %>
                <%= if item.id == "tienda" and @current_page in ["tienda", "categorias", "carrusel", "super_categorias", "secciones",
                      "seccion_top10", "seccion_favoritos", "seccion_destacados", "seccion_publicidad", "seccion_envios",
                      "productos_nativos", "clientes_nativos", "listas_precios", "lista_productos",
                      "stock", "sucursales"] and
                    (can_see_categorias?(@user_role, @user_permissions) or
                     (@modo_nativo and can_see_clientes_nativos?(@user_role, @user_permissions))) do %>
                  <div class="pc-submenu">
                    <%= if can_see_categorias?(@user_role, @user_permissions) do %>
                      <!-- Desktop: enlace directo a secciones (sin dropdown) -->
                      <div class="hidden md:block">
                        <button
                          type="button"
                          class={submenu_item_class("secciones", @current_page) <> " w-full text-left"}
                          phx-click={@menu_event}
                          phx-value-id="secciones"
                        >
                          <span class="pc-submenu-dot" />
                          <span class="pc-nav-label">Administrar</span>
                        </button>
                      </div>
                      <!-- Móvil: dropdown con todos los links -->
                      <div class="md:hidden">
                        <button
                          type="button"
                          class={"flex items-center justify-between w-full " <> submenu_item_class("secciones", @current_page)}
                          phx-click={JS.toggle(to: "#admin-mobile-menu")}
                        >
                          <span class="flex items-center gap-1.5">
                            <span class="pc-submenu-dot" />
                            <span class="pc-nav-label">Administrar</span>
                          </span>
                          <svg class="w-3 h-3 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                          </svg>
                        </button>
                        <div id="admin-mobile-menu" class={if @current_page in ["categorias","super_categorias","productos_nativos","carrusel","secciones","stock","sucursales","seccion_top10","seccion_favoritos","seccion_destacados","seccion_publicidad","seccion_envios"], do: "block", else: "hidden"}>
                          <div class="pl-3 pt-1 pb-1 space-y-0.5">
                            <p class="text-[9px] font-bold text-gray-400 uppercase tracking-widest px-2 pt-1 pb-0.5">Catálogo</p>
                            <button type="button" class={mobile_admin_item_class("categorias", @current_page)} phx-click={@menu_event} phx-value-id="categorias">Categorías</button>
                            <button type="button" class={mobile_admin_item_class("super_categorias", @current_page)} phx-click={@menu_event} phx-value-id="super_categorias">Super Categorías</button>
                            <button type="button" class={mobile_admin_item_class("productos_nativos", @current_page)} phx-click={@menu_event} phx-value-id="productos_nativos">Productos</button>
                            <p class="text-[9px] font-bold text-gray-400 uppercase tracking-widest px-2 pt-2 pb-0.5">Tienda</p>
                            <button type="button" class={mobile_admin_item_class("carrusel", @current_page)} phx-click={@menu_event} phx-value-id="carrusel">Carrusel</button>
                            <button type="button" class={mobile_admin_item_class("secciones", @current_page)} phx-click={@menu_event} phx-value-id="secciones">Secciones</button>
                            <button type="button" class={mobile_admin_item_class("stock", @current_page)} phx-click={@menu_event} phx-value-id="stock">Stock</button>
                            <button type="button" class={mobile_admin_item_class("sucursales", @current_page)} phx-click={@menu_event} phx-value-id="sucursales">Sucursales</button>
                            <p class="text-[9px] font-bold text-gray-400 uppercase tracking-widest px-2 pt-2 pb-0.5">Contenido</p>
                            <button type="button" class={mobile_admin_item_class("seccion_top10", @current_page)} phx-click={@menu_event} phx-value-id="seccion_top10">Top 10</button>
                            <button type="button" class={mobile_admin_item_class("seccion_favoritos", @current_page)} phx-click={@menu_event} phx-value-id="seccion_favoritos">Favoritos</button>
                            <button type="button" class={mobile_admin_item_class("seccion_destacados", @current_page)} phx-click={@menu_event} phx-value-id="seccion_destacados">Destacados</button>
                            <button type="button" class={mobile_admin_item_class("seccion_publicidad", @current_page)} phx-click={@menu_event} phx-value-id="seccion_publicidad">Publicidad</button>
                            <button type="button" class={mobile_admin_item_class("seccion_envios", @current_page)} phx-click={@menu_event} phx-value-id="seccion_envios">Envíos</button>
                          </div>
                        </div>
                      </div>
                    <% end %>
                    <!-- Toggle Clientes Nativos: solo si puede ver clientes -->
                    <%= if not @modo_nativo or can_see_clientes_nativos?(@user_role, @user_permissions) do %>
                      <button
                        type="button"
                        class={submenu_item_class("clientes_nativos", @current_page) <> " flex items-center justify-between w-full"}
                        phx-click={@menu_event}
                        phx-value-id="toggle_prettycore_children"
                      >
                        <span class="flex items-center gap-1.5">
                          <span class="pc-submenu-dot" />
                          <span class="pc-nav-label">Clientes</span>
                        </span>
                        <svg class={"w-3 h-3 flex-shrink-0 transition-transform #{if @show_prettycore_children or @current_page in ["clientes_nativos","listas_precios","lista_productos"], do: "rotate-180", else: ""}"}
                          fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/>
                        </svg>
                      </button>
                      <%= if @show_prettycore_children or @current_page in ["clientes_nativos", "listas_precios", "lista_productos"] do %>
                        <div class="pc-subsubmenu">
                          <button type="button"
                            class={subsubmenu_item_class("clientes_nativos", @current_page)}
                            phx-click={@menu_event} phx-value-id="clientes_nativos">
                            <span class="pc-subsubmenu-dot" />
                            <span class="pc-nav-label">Clientes</span>
                          </button>
                          <button type="button"
                            class={subsubmenu_item_class("listas_precios", @current_page)}
                            phx-click={@menu_event} phx-value-id="listas_precios">
                            <span class="pc-subsubmenu-dot" />
                            <span class="pc-nav-label">Lista de Precios</span>
                          </button>
                          <button type="button"
                            class={subsubmenu_item_class("productos_nativos", @current_page)}
                            phx-click={@menu_event} phx-value-id="lista_productos">
                            <span class="pc-subsubmenu-dot" />
                            <span class="pc-nav-label">Lista de Productos</span>
                          </button>
                        </div>
                      <% end %>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </nav>
          </div>

          <!-- SECCIÓN INFERIOR -->
          <div>
            <div class="pc-sidebar-section-label">Cuenta</div>
            <nav class="pc-sidebar-nav">
              <!-- USUARIO -->
              <div class="pc-sidebar-user">
                <div class="pc-sidebar-user-avatar">
                  <%= if @company_logo do %>
                    <img src={@company_logo} alt="Logo" class="pc-sidebar-user-avatar-img" />
                  <% else %>
                    {((@current_user_name && String.first(@current_user_name)) || "?") |> String.upcase()}
                  <% end %>
                </div>
                <span class="pc-nav-label">{@current_user_name || "Usuario"}</span>
              </div>
              <!-- LOGOUT -->
              <.link
                href="/logout"
                class="pc-nav-item pc-nav-logout"
                data-confirm="¿Cerrar sesión?"
              >
                <span class="pc-nav-icon"><.pc_icon name="logout" /></span>
                <span class="pc-nav-label">Cerrar sesión</span>
              </.link>
            </nav>
          </div>
        </div>
        </aside>
        <!-- CONTENIDO -->
        <main class="pc-platform-main">
          <!-- Banner carrusel -->
          <div class="w-full bg-gradient-to-r from-indigo-600 via-purple-600 to-indigo-600 overflow-hidden whitespace-nowrap">
            <div class="inline-flex animate-marquee">
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
              <span class="px-8 py-2 text-sm font-semibold text-white tracking-wide">
                ¿Tienes alguna idea de app web y no sabes cómo hacerla realidad? CONTÁCTANOS
              </span>
            </div>
          </div>
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  ## ICONOS — outline style
  attr :name, :string, required: true

  def pc_icon(assigns) do
    ~H"""
    <%= case @name do %>
      <% "inicio" -> %>
        <img src="/images/inicio.png" class="w-8 h-8 object-contain" />
      <% "programacion" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <rect x="2" y="3" width="20" height="14" rx="2" />
          <line x1="8" y1="21" x2="16" y2="21" />
          <line x1="12" y1="17" x2="12" y2="21" />
        </svg>
      <% "workorder" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" />
          <rect x="9" y="3" width="6" height="4" rx="1" />
          <line x1="9" y1="12" x2="15" y2="12" />
          <line x1="9" y1="16" x2="13" y2="16" />
        </svg>
      <% "clientes" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      <% "config" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
        </svg>
      <% "programacion_sql" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <ellipse cx="12" cy="5" rx="9" ry="3" />
          <path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3" />
          <path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" />
        </svg>
      <% "tienda" -> %>
        <img src="/images/tienda.png" class="w-8 h-8 object-contain" />
      <% "pedidos" -> %>
        <img src="/images/pedidos.png" class="w-8 h-8 object-contain" />
      <% "usuarios" -> %>
        <img src="/images/usuarios.png" class="w-8 h-8 object-contain" />
      <% "categorias" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <rect x="3" y="3" width="7" height="7" rx="1.5" />
          <rect x="14" y="3" width="7" height="7" rx="1.5" />
          <rect x="3" y="14" width="7" height="7" rx="1.5" />
          <rect x="14" y="14" width="7" height="7" rx="1.5" />
        </svg>
      <% "logout" -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
          <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
          <polyline points="16 17 21 12 16 7" />
          <line x1="21" y1="12" x2="9" y2="12" />
        </svg>
      <% _ -> %>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
          <circle cx="12" cy="12" r="8" />
        </svg>
    <% end %>
    """
  end

  ## FILTRO DE MENÚ
  defp filter_menu(menu, perms, role, modo_nativo \\ false) do
    menu
    |> then(fn m -> if modo_nativo, do: Enum.reject(m, &(&1.id == "clientes")), else: m end)
    |> do_filter_menu(perms, role)
  end

  defp do_filter_menu(menu, _perms, "sysadmin"), do: menu
  defp do_filter_menu(menu, nil, "user"), do: Enum.filter(menu, &(&1.id == "inicio"))
  defp do_filter_menu(menu, nil, _role), do: Enum.reject(menu, &Map.get(&1, :admin_only, false))
  defp do_filter_menu(menu, perms, _role) do
    menu
    |> Enum.reject(fn item -> Map.get(item, :admin_only, false) and item.id not in perms end)
    |> Enum.filter(&(&1.id in perms))
  end

  ## HELPERS
  defp menu_active?("programacion", current)
       when current in ["programacion", "programacion_sql"],
       do: true

  defp menu_active?("tienda", current)
       when current in ["tienda", "categorias", "carrusel", "super_categorias", "secciones",
                        "seccion_top10", "seccion_favoritos", "seccion_destacados",
                        "seccion_publicidad", "seccion_envios", "productos_nativos",
                        "clientes_nativos", "listas_precios", "lista_productos",
                        "stock", "sucursales"],
       do: true

  defp menu_active?("clientes", current)
       when current in ["clientes"],
       do: true

  defp menu_active?("pedidos", "pedidos"), do: true

  defp menu_active?(id, current), do: id == current

  defp can_see_categorias?("sysadmin", _perms), do: true
  defp can_see_categorias?(_role, nil), do: false
  defp can_see_categorias?(_role, perms), do: "categorias" in perms or "administrar" in perms

  defp can_see_clientes_nativos?("sysadmin", _perms), do: true
  defp can_see_clientes_nativos?(_role, nil), do: false
  defp can_see_clientes_nativos?(_role, perms), do: "clientes" in perms

  defp menu_item_class(true), do: "pc-nav-item pc-nav-item-active"
  defp menu_item_class(false), do: "pc-nav-item"

  defp submenu_item_class(id, current),
    do: if(id == current, do: "pc-submenu-item pc-submenu-item-active", else: "pc-submenu-item")

  defp subsubmenu_item_class(id, current),
    do: if(id == current, do: "pc-subsubmenu-item pc-subsubmenu-item-active", else: "pc-subsubmenu-item")

  defp mobile_admin_item_class(id, current),
    do: "w-full text-left px-2 py-1.5 text-xs rounded-lg transition-colors " <>
        if(id == current, do: "bg-purple-100 text-purple-700 font-semibold", else: "text-gray-700 hover:bg-gray-100")

  defp toggle_sidebar_js(menu_event) do
    JS.push(menu_event, value: %{id: "toggle_sidebar"})
    |> JS.toggle_class("pc-sidebar-visible", to: ".pc-platform-sidebar")
    |> JS.toggle_class("pc-sidebar-overlay-visible", to: ".pc-sidebar-overlay")
  end

  defp mobile_toggle_js do
    JS.toggle_class("pc-sidebar-visible", to: ".pc-platform-sidebar")
    |> JS.toggle_class("pc-sidebar-overlay-visible", to: ".pc-sidebar-overlay")
  end

  # ── Panel de navegación entre secciones ─────────────────────────
  # Úsalo con <PrettycoreWeb.MenuLayout.secciones_panel current_page={@current_page} />

  attr :current_page, :string, required: true

  def secciones_panel(assigns) do
    ~H"""
    <aside class="hidden md:flex flex-col w-72 flex-shrink-0 p-4 gap-3 bg-gray-100 self-start sticky top-0 min-h-screen overflow-y-auto" style="max-height:100vh;">

      <!-- Grupo: Catálogo -->
      <div>
        <p class="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-1">Catálogo</p>
        <div class="bg-white rounded-2xl overflow-hidden shadow-sm divide-y divide-gray-100">
          <.sp_item img="/images/categorias.png" label="Categorías"       href="/admin/categorias"         active={@current_page == "categorias"} />
          <.sp_item img="/images/supercat.png"  label="Super Categorías"  href="/admin/super-categorias"   active={@current_page == "super_categorias"} />
          <.sp_item img="/images/productos.png" label="Productos"         href="/admin/productos-nativos"  active={@current_page == "productos_nativos"} />
        </div>
      </div>

      <!-- Grupo: Tienda -->
      <div>
        <p class="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-1">Tienda</p>
        <div class="bg-white rounded-2xl overflow-hidden shadow-sm divide-y divide-gray-100">
          <.sp_item img="/images/secciones.png" label="Secciones" href="/admin/secciones" active={@current_page == "secciones"} />
          <.sp_item img="/images/carrusel.png"   label="Carrusel"   href="/admin/carrusel"   active={@current_page == "carrusel"} />
          <.sp_item img="/images/stock.png"     label="Stock"     href="/admin/stock"     active={@current_page == "stock"} />
          <.sp_item img="/images/sucursales.png" label="Sucursales" href="/admin/sucursales" active={@current_page == "sucursales"} />
        </div>
      </div>

      <!-- Grupo: Secciones editables -->
      <div>
        <p class="text-[10px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-1">Contenido</p>
        <div class="bg-white rounded-2xl overflow-hidden shadow-sm divide-y divide-gray-100">
          <.sp_item img="/images/top10.png"      label="Top 10"     href="/admin/seccion/top10"      active={@current_page == "seccion_top10"} />
          <.sp_item img="/images/favoritos.png"  label="Favoritos"  href="/admin/seccion/favoritos"  active={@current_page == "seccion_favoritos"} />
          <.sp_item img="/images/destacados.png" label="Destacados" href="/admin/seccion/destacados" active={@current_page == "seccion_destacados"} />
          <.sp_item img="/images/publicidad.png" label="Publicidad"  href="/admin/seccion/publicidad" active={@current_page == "seccion_publicidad"} />
          <.sp_item img="/images/envios.png"     label="Envíos"      href="/admin/seccion/envios"     active={@current_page == "seccion_envios"} />
        </div>
      </div>

    </aside>
    """
  end

  attr :icon, :string, default: nil
  attr :label, :string, required: true
  attr :href, :string, required: true
  attr :active, :boolean, default: false
  attr :img, :string, default: nil

  defp sp_item(assigns) do
    ~H"""
    <a href={@href}
      class={"flex items-center gap-3 px-4 py-3.5 transition-colors cursor-pointer group #{if @active, do: "bg-purple-50", else: "hover:bg-gray-50 active:bg-gray-100"}"}>
      <%= if @img do %>
        <img src={@img} class="w-8 h-8 flex-shrink-0 object-contain" />
      <% else %>
        <span class="text-2xl leading-none w-10 text-center flex-shrink-0"><%= @icon %></span>
      <% end %>
      <span class={"flex-1 text-base font-medium whitespace-nowrap #{if @active, do: "text-purple-700 font-semibold", else: "text-gray-800 group-hover:text-gray-900"}"}><%= @label %></span>
      <%= if @active do %>
        <div class="w-2 h-2 rounded-full bg-purple-500 flex-shrink-0"></div>
      <% else %>
        <svg class="w-4 h-4 text-gray-300 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 5l7 7-7 7" />
        </svg>
      <% end %>
    </a>
    """
  end
end
