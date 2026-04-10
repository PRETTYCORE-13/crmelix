defmodule PrettycoreWeb.ConfiguracionLive do
  use PrettycoreWeb, :live_view_admin

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "config")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:sidebar_open, true)
     |> assign(:current_path, "/admin/configuracion")}
  end

  # -----------------------------------------------------
  # NAV CENTRALIZADA (MODELO 2)
  # -----------------------------------------------------
  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    email = socket.assigns.current_user_email

    case id do
      "toggle_sidebar" ->
        {:noreply, update(socket, :sidebar_open, &(not &1))}

      "inicio" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/platform")}

      "programacion" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/programacion")}

      "programacion_sql" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/programacion/sql")}

      "workorder" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/workorder")}

      "clientes" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/clientes")}

   #   "config" ->
        # ya estás aquí
  #    {:noreply, push_navigate(socket, to: ~p"/admin/configuracion")}

      _ ->
        {:noreply, socket}
    end
  end

  # -----------------------------------------------------
  # RENDER
  # -----------------------------------------------------
  @impl true
  def render(assigns) do
    ~H"""
    <section class="config-page">
      <!-- TÍTULO -->
      <div class="config-header">
        <h1 class="config-title">Settings</h1>
      </div>
      <!-- CONTENEDOR PRINCIPAL -->
      <div class="config-container">
        <!-- NOTIFICATION SETTINGS -->
        <div class="config-block">
          <h2 class="block-title">Notification settings</h2>

          <p class="block-subtitle">
            By default, designers will be notified by your company's preferred dark patterns.
          </p>
          <!-- PRIMARY SETTINGS -->
          <div class="settings-group">
            <h3 class="group-title">Primary settings</h3>

            <div class="setting-row">
              <div>
                <p class="setting-title">Setting option disabled</p>

                <p class="setting-desc">Due to a broken third-party system</p>
              </div>
              <label class="switch"><input type="checkbox" /> <span class="slider"></span></label>
            </div>

            <div class="setting-row">
              <div>
                <p class="setting-title">Automatically text alignment</p>

                <p class="setting-desc">This is a cross-experimental feature</p>
              </div>

              <label class="switch">
                <input type="checkbox" checked /> <span class="slider"></span>
              </label>
            </div>
          </div>
          <!-- SECONDARY SETTINGS -->
          <div class="settings-group">
            <h3 class="group-title">Secondary settings</h3>

            <div class="setting-row">
              <div>
                <p class="setting-title">Setting option disabled</p>

                <p class="setting-desc">This is also broken</p>
              </div>
              <label class="switch"><input type="checkbox" /> <span class="slider"></span></label>
            </div>

            <div class="setting-row">
              <div>
                <p class="setting-title">Automatically delete items</p>

                <p class="setting-desc">Get rid of unused files</p>
              </div>

              <label class="switch">
                <input type="checkbox" checked /> <span class="slider"></span>
              </label>
            </div>

            <div class="setting-row">
              <div>
                <p class="setting-title">Keep my financial information</p>

                <p class="setting-desc">No more privacy on the web</p>
              </div>

              <label class="switch">
                <input type="checkbox" checked /> <span class="slider"></span>
              </label>
            </div>
          </div>
          <!-- CHECKBOX OPTIONS -->
          <div class="settings-group">
            <h3 class="group-title">Checkbox items</h3>

            <div class="check-row">
              <input type="checkbox" checked /> <span>For commercial projects</span>
            </div>

            <div class="check-row">
              <input type="checkbox" checked /> <span>Accelerate design flow</span>
            </div>

            <div class="check-row"><input type="checkbox" /> <span>Available for download</span></div>
          </div>
        </div>
        <!-- EDIT DETAILS BLOCK -->
        <div class="config-block">
          <h2 class="block-title">Edit details</h2>

          <p class="block-subtitle">
            This design system provides variations of inputs and settings. Mix and reuse.
          </p>

          <div class="form-grid">
            <div class="form-field">
              <label>Your name</label> <input type="text" value="Roman Kamushken" />
            </div>

            <div class="form-field">
              <label>Email</label> <input type="email" value="kamushken@gmail.com" />
            </div>

            <div class="form-field">
              <label>Timezone</label>
              <select>
                <option>(+00:00) Europe/London</option>
              </select>
            </div>

            <div class="form-field">
              <label>Locale</label>
              <select>
                <option>English (United Kingdom)</option>
              </select>
            </div>

            <div class="form-field">
              <label>Language</label>
              <select>
                <option>English (US)</option>
              </select>
            </div>

            <div class="form-field">
              <label>Default currency</label>
              <select>
                <option>Bitcoin</option>
              </select>
            </div>
            <!-- PROFILE PICTURE -->
            <div class="form-field full"><label>Profile picture</label> <input type="file" /></div>
          </div>
          <button class="save-btn">Save changes</button>
        </div>
      </div>
    </section>
    """
  end
end
