defmodule PrettycoreWeb.SysAdminLayout do
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  attr :current_page, :string, required: true
  attr :current_user_name, :string, default: "SYSADMIN"
  slot :inner_block, required: true

  def sidebar(assigns) do
    ~H"""
    <div class="pc-platform">
      <!-- Barra negra superior -->
      <div class="pc-topbar">
        <img
          src="https://prettycore.xyz/IMAGENES/PRETTYCORE_NEGRO.png"
          alt="PRETTYCORE"
          class="pc-topbar-logo"
        />
      </div>
      <!-- Fila: Sidebar + Contenido -->
      <div class="pc-platform-row">
        <!-- Mobile hamburger button -->
        <button
          type="button"
          class="pc-mobile-menu-btn"
          phx-click={mobile_toggle_js()}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="3" y1="6" x2="21" y2="6" /><line x1="3" y1="12" x2="21" y2="12" /><line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>
        <!-- Mobile overlay -->
        <div class="pc-sidebar-overlay" phx-click={mobile_toggle_js()} />
        <!-- Sidebar -->
        <aside class="pc-platform-sidebar pc-platform-sidebar-open">
          <!-- HEADER -->
          <div class="pc-sidebar-header">
            <div class="pc-sidebar-brand">
              <img
                src="https://prettycore.xyz/IMAGENES/Logo%20Prettycore%20(8).png"
                alt="PrettyCore"
                class="pc-sidebar-drop-logo"
              />
            </div>
          </div>

          <!-- CUERPO DEL MENÚ -->
          <div class="pc-sidebar-body">
            <div>
              <div class="pc-sidebar-section-label">Admin</div>
              <nav class="pc-sidebar-nav">
                <.link
                  navigate="/sysadmin/configuracion"
                  class={if @current_page == "configuracion", do: "pc-nav-item pc-nav-item-active", else: "pc-nav-item"}
                >
                  <span class="pc-nav-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <circle cx="12" cy="12" r="3" />
                      <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                    </svg>
                  </span>
                  <span class="pc-nav-label">Configuración</span>
                </.link>

                <.link
                  navigate="/sysadmin/sesiones"
                  class={if @current_page == "sesiones", do: "pc-nav-item pc-nav-item-active", else: "pc-nav-item"}
                >
                  <span class="pc-nav-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                      <circle cx="9" cy="7" r="4" />
                      <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                      <path d="M16 3.13a4 4 0 0 1 0 7.75" />
                    </svg>
                  </span>
                  <span class="pc-nav-label">Sesiones</span>
                </.link>

                <.link
                  navigate="/sysadmin/usuarios"
                  class={if @current_page == "usuarios", do: "pc-nav-item pc-nav-item-active", else: "pc-nav-item"}
                >
                  <span class="pc-nav-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                      <circle cx="9" cy="7" r="4" />
                      <line x1="19" y1="8" x2="23" y2="8" />
                      <line x1="21" y1="6" x2="21" y2="10" />
                    </svg>
                  </span>
                  <span class="pc-nav-label">Usuarios</span>
                </.link>

              </nav>
            </div>

            <!-- SECCIÓN INFERIOR -->
            <div>
              <div class="pc-sidebar-section-label">Cuenta</div>
              <nav class="pc-sidebar-nav">
                <div class="pc-sidebar-user">
                  <div class="pc-sidebar-user-avatar">
                    {(String.first(@current_user_name || "?") || "?") |> String.upcase()}
                  </div>
                  <span class="pc-nav-label">{@current_user_name}</span>
                </div>
                <.link
                  href="/logout"
                  class="pc-nav-item pc-nav-logout"
                  data-confirm="¿Cerrar sesión?"
                >
                  <span class="pc-nav-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
                      <polyline points="16 17 21 12 16 7" />
                      <line x1="21" y1="12" x2="9" y2="12" />
                    </svg>
                  </span>
                  <span class="pc-nav-label">Cerrar sesión</span>
                </.link>
              </nav>
            </div>
          </div>
        </aside>

        <!-- CONTENIDO -->
        <main class="pc-platform-main">
          {render_slot(@inner_block)}
        </main>
      </div>
    </div>
    """
  end

  defp mobile_toggle_js do
    JS.toggle_class("pc-sidebar-visible", to: ".pc-platform-sidebar")
    |> JS.toggle_class("pc-sidebar-overlay-visible", to: ".pc-sidebar-overlay")
  end
end
