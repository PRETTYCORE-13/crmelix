defmodule PrettycoreWeb.SysAdmin.UsuariosLive do
  use PrettycoreWeb, :live_view

  import PrettycoreWeb.SysAdminLayout

  alias Prettycore.Auth
  alias Prettycore.Auth.AuthUser

  @impl true
  def mount(_params, _session, socket) do
    changeset = AuthUser.changeset(%AuthUser{}, %{})

    {:ok,
     socket
     |> assign(:current_page, "usuarios")
     |> assign(:page_title, "Usuarios")
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))
     |> assign(:users, Auth.list_users())
     |> assign(:show_password, false)
     |> assign(:expanded_permissions_user_id, nil)}
  end

  @impl true
  def handle_event("validate", %{"auth_user" => params}, socket) do
    changeset =
      %AuthUser{}
      |> AuthUser.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"auth_user" => params}, socket) do
    case Auth.create_user(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Usuario creado exitosamente")
         |> assign(:form, to_form(AuthUser.changeset(%AuthUser{}, %{})))
         |> assign(:users, Auth.list_users())}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("toggle_password", _, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Auth.get_user(id)

    cond do
      user && user.role == "sysadmin" ->
        {:noreply, put_flash(socket, :error, "El perfil sysadmin no puede eliminarse")}
      user ->
        case Auth.delete_user(user) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Usuario eliminado")
             |> assign(:users, Auth.list_users())}
          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar usuario")}
        end
      true ->
        {:noreply, put_flash(socket, :error, "Usuario no encontrado")}
    end
  end

  @impl true
  def handle_event("toggle_permissions_panel", %{"id" => id}, socket) do
    expanded =
      if socket.assigns.expanded_permissions_user_id == id, do: nil, else: id
    {:noreply, assign(socket, :expanded_permissions_user_id, expanded)}
  end

  @impl true
  def handle_event("toggle_permission", %{"user-id" => user_id, "permission" => permission}, socket) do
    user = Auth.get_user(user_id)

    if user do
      case Auth.toggle_permission(user, permission) do
        {:ok, _} ->
          {:noreply, assign(socket, :users, Auth.list_users())}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al actualizar permisos")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    user = Auth.get_user(id)

    if user do
      case Auth.update_user(user, %{active: !user.active}) do
        {:ok, _} ->
          {:noreply,
           socket
           |> put_flash(:info, "Estado actualizado")
           |> assign(:users, Auth.list_users())}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al actualizar")}
      end
    else
      {:noreply, put_flash(socket, :error, "Usuario no encontrado")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <div class="min-h-screen bg-black py-10">
        <div class="px-4">
          <!-- Header -->
          <div class="mb-10 text-center">
            <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-zinc-900 border border-zinc-800 mb-4">
              <svg class="w-8 h-8 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
              </svg>
            </div>
            <h1 class="text-3xl font-bold text-white">Administrar Usuarios</h1>
            <p class="mt-2 text-zinc-500">Crear y gestionar usuarios del sistema</p>
          </div>

          <div class="grid grid-cols-2 gap-6">
            <!-- Formulario -->
            <div class="bg-zinc-950 border border-zinc-800 rounded-2xl p-8 shadow-2xl">
              <div class="flex items-center space-x-3 mb-8">
                <div class="w-10 h-10 rounded-xl bg-zinc-900 border border-zinc-800 flex items-center justify-center">
                  <svg class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                  </svg>
                </div>
                <h2 class="text-xl font-semibold text-white">Crear Nuevo Usuario</h2>
              </div>

              <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
                <!-- Username -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">
                    Usuario <span class="text-purple-500">*</span>
                  </label>
                  <input
                    type="text"
                    name="auth_user[username]"
                    value={@form[:username].value}
                    maxlength="50"
                    class={"block w-full px-4 py-3 bg-black border rounded-xl text-white placeholder-zinc-600 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all #{if @form[:username].errors != [], do: "border-red-500", else: "border-zinc-800"}"}
                    placeholder="nombre_usuario"
                    autocomplete="off"
                  />
                  <%= if @form[:username].errors != [] do %>
                    <p class="mt-1 text-sm text-red-400"><%= translate_error(hd(@form[:username].errors)) %></p>
                  <% end %>
                </div>

                <!-- Usuario FROG -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Usuario FROG</label>
                  <input
                    type="text"
                    name="auth_user[usuario_frog]"
                    value={@form[:usuario_frog].value}
                    maxlength="50"
                    class="block w-full px-4 py-3 bg-black border border-zinc-800 rounded-xl text-white placeholder-zinc-600 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all"
                    placeholder="Usuario FROG"
                    autocomplete="off"
                  />
                </div>

                <!-- Email -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Email</label>
                  <input
                    type="email"
                    name="auth_user[email]"
                    value={@form[:email].value}
                    maxlength="100"
                    class="block w-full px-4 py-3 bg-black border border-zinc-800 rounded-xl text-white placeholder-zinc-600 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all"
                    placeholder="usuario@ejemplo.com"
                    autocomplete="off"
                  />
                </div>

                <!-- Password -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">
                    Contraseña <span class="text-purple-500">*</span>
                  </label>
                  <div class="relative">
                    <input
                      type={if @show_password, do: "text", else: "password"}
                      name="auth_user[password]"
                      value={@form[:password].value}
                      maxlength="72"
                      class={"block w-full pr-12 px-4 py-3 bg-black border rounded-xl text-white placeholder-zinc-600 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all #{if @form[:password].errors != [], do: "border-red-500", else: "border-zinc-800"}"}
                      placeholder="Mínimo 6 caracteres"
                      autocomplete="new-password"
                    />
                    <button type="button" phx-click="toggle_password" class="absolute inset-y-0 right-0 flex items-center pr-3 text-zinc-500 hover:text-white transition-colors">
                      <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <%= if @show_password do %>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                        <% else %>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                        <% end %>
                      </svg>
                    </button>
                  </div>
                  <%= if @form[:password].errors != [] do %>
                    <p class="mt-1 text-sm text-red-400"><%= translate_error(hd(@form[:password].errors)) %></p>
                  <% end %>
                </div>

                <!-- Role -->
                <div>
                  <label class="block text-sm font-medium text-zinc-300 mb-2">Rol</label>
                  <select
                    name="auth_user[role]"
                    class="block w-full px-4 py-3 bg-black border border-zinc-800 rounded-xl text-white focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all appearance-none cursor-pointer"
                  >
                    <option value="user" selected={@form[:role].value == "user"} class="bg-black">Cliente</option>
                    <option value="admin" selected={@form[:role].value == "admin"} class="bg-black">Administrador</option>
                    <option value="oficina" selected={@form[:role].value == "oficina"} class="bg-black">Oficina</option>
                    <option value="sysadmin" selected={@form[:role].value == "sysadmin"} class="bg-black">ECORE</option>
                  </select>
                </div>

                <input type="hidden" name="auth_user[active]" value="true" />

                <div class="pt-4">
                  <button
                    type="submit"
                    class="w-full flex justify-center items-center py-3.5 px-4 rounded-xl text-sm font-semibold text-white bg-purple-600 hover:bg-purple-500 transition-all duration-200"
                  >
                    Crear Usuario
                  </button>
                </div>
              </.form>
            </div>

            <!-- Lista de Usuarios -->
            <div class="bg-zinc-950 border border-zinc-800 rounded-2xl p-8 shadow-2xl">
              <div class="flex items-center justify-between mb-8">
                <h2 class="text-xl font-semibold text-white">Usuarios Registrados</h2>
                <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-zinc-900 text-zinc-400 border border-zinc-800">
                  <%= length(@users) %> usuarios
                </span>
              </div>

              <%= if Enum.empty?(@users) do %>
                <div class="text-center py-12">
                  <p class="text-zinc-400">No hay usuarios registrados</p>
                </div>
              <% else %>
                <div class="space-y-2">
                  <% all_perms = [
                    {"clientes",        "Clientes",            :page},
                    {"tienda",          "Tienda",              :page},
                    {"administrar",     "Administrar Tienda",  :page},
                    {"pedidos",         "Ver Pedidos",         :page},
                    {"usuarios",        "Usuarios",            :page},
                    {"editar_imagenes", "Imágenes Tienda",     :feature}
                  ] %>
                  <%= for user <- @users do %>
                    <% expanded = @expanded_permissions_user_id == user.id %>
                    <% user_perms = user.permissions || ["tienda"] %>
                    <div class={"rounded-xl border transition-all duration-200 #{if expanded, do: "border-purple-600/40 bg-zinc-900", else: "border-zinc-800 bg-zinc-900/50 hover:bg-zinc-900 hover:border-zinc-700"}"}>
                      <div class="flex items-center justify-between p-4">
                        <div class="flex items-center space-x-4">
                          <div class={"w-12 h-12 rounded-xl flex items-center justify-center text-white font-bold text-lg #{if user.active, do: "bg-purple-600", else: "bg-zinc-700"}"}>
                            <%= (String.first(user.username || "?") || "?") |> String.upcase() %>
                          </div>
                          <div>
                            <p class="text-sm font-semibold text-white"><%= user.username %></p>
                            <p class="text-xs text-zinc-500 mt-0.5"><%= user.email || "Sin email" %></p>
                          </div>
                        </div>
                        <div class="flex items-center space-x-2">
                          <span class={"inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium #{case user.role do
                            "sysadmin" -> "bg-amber-500/10 text-amber-400 border border-amber-500/20"
                            "admin"    -> "bg-purple-600/10 text-purple-400 border border-purple-600/20"
                            "oficina"  -> "bg-blue-500/10 text-blue-400 border border-blue-500/20"
                            _          -> "bg-zinc-800 text-zinc-500 border border-zinc-700"
                          end}"}>
                            <%= case user.role do
                              "admin"    -> "Administrador"
                              "sysadmin" -> "ECORE"
                              "oficina"  -> "Oficina"
                              _          -> "Cliente"
                            end %>
                          </span>
                          <!-- Botón permisos -->
                          <button
                            type="button"
                            phx-click="toggle_permissions_panel"
                            phx-value-id={user.id}
                            class={"p-1.5 rounded-lg transition-all duration-200 #{if expanded, do: "text-purple-400 bg-purple-600/10", else: "text-zinc-600 hover:text-purple-400 hover:bg-purple-600/10"}"}
                            title="Gestionar permisos"
                          >
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                              <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                            </svg>
                          </button>
                          <!-- Botón eliminar (nunca para sysadmin) -->
                          <%= if user.role != "sysadmin" do %>
                            <button
                              type="button"
                              phx-click="delete_user"
                              phx-value-id={user.id}
                              data-confirm={"¿Eliminar a #{user.username}? Esta acción no se puede deshacer."}
                              class="p-1.5 text-zinc-600 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all duration-200"
                              title="Eliminar usuario"
                            >
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                <polyline points="3 6 5 6 21 6" />
                                <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
                                <path d="M10 11v6M14 11v6" />
                                <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                              </svg>
                            </button>
                          <% end %>
                          <!-- Toggle activo -->
                          <button
                            type="button"
                            phx-click="toggle_active"
                            phx-value-id={user.id}
                            class={"relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-300 ease-in-out focus:outline-none #{if user.active, do: "bg-purple-600", else: "bg-zinc-700"}"}
                          >
                            <span class={"pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-lg ring-0 transition duration-300 ease-in-out #{if user.active, do: "translate-x-5", else: "translate-x-0"}"}></span>
                          </button>
                        </div>
                      </div>
                      <!-- Panel de permisos — SYSADMIN puede toglear todo sin restricción -->
                      <%= if expanded do %>
                        <div class="px-4 pb-4 border-t border-zinc-800/60 pt-3">
                          <table class="w-full text-xs">
                            <thead>
                              <tr>
                                <th class="text-left text-zinc-500 font-medium pb-2 pr-4">Permiso</th>
                                <th class="text-left text-zinc-500 font-medium pb-2">Acceso</th>
                              </tr>
                            </thead>
                            <tbody class="divide-y divide-zinc-800/40">
                              <%= for {perm_id, perm_label, perm_type} <- all_perms do %>
                                <% checked = perm_id in user_perms %>
                                <tr>
                                  <td class="py-2 pr-4">
                                    <div class="flex items-center gap-2">
                                      <%= case perm_id do %>
                                        <% "inicio" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M3 9.5L12 4l9 5.5" /><path d="M19 13v6a1 1 0 0 1-1 1h-4v-5h-4v5H6a1 1 0 0 1-1-1v-6" />
                                          </svg>
                                        <% "clientes" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
                                          </svg>
                                        <% "tienda" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" /><line x1="3" y1="6" x2="21" y2="6" /><path d="M16 10a4 4 0 0 1-8 0" />
                                          </svg>
                                        <% "administrar" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                                          </svg>
                                        <% "pedidos" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2" /><rect x="9" y="3" width="6" height="4" rx="1" /><line x1="9" y1="12" x2="15" y2="12" /><line x1="9" y1="16" x2="13" y2="16" />
                                          </svg>
                                        <% "usuarios" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><line x1="19" y1="8" x2="23" y2="8" /><line x1="21" y1="6" x2="21" y2="10" />
                                          </svg>
                                        <% "editar_imagenes" -> %>
                                          <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                            <path d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                                            <path d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                                          </svg>
                                        <% _ -> %>
                                      <% end %>
                                      <span class={if checked, do: "text-zinc-300", else: "text-zinc-600"}>
                                        <%= perm_label %>
                                        <%= if perm_type == :feature do %>
                                          <span class="ml-1 text-[10px] text-amber-500/70 font-medium">función</span>
                                        <% end %>
                                      </span>
                                    </div>
                                  </td>
                                  <td class="py-2">
                                    <!-- SYSADMIN: sin restricciones, toggle siempre activo -->
                                    <button
                                      type="button"
                                      phx-click="toggle_permission"
                                      phx-value-user-id={user.id}
                                      phx-value-permission={perm_id}
                                      class={"relative inline-flex h-5 w-9 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none #{if checked, do: "bg-purple-600", else: "bg-zinc-700"}"}
                                      title={if checked, do: "Quitar permiso", else: "Dar permiso"}
                                    >
                                      <span class={"pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm transition duration-200 ease-in-out #{if checked, do: "translate-x-4", else: "translate-x-0"}"}></span>
                                    </button>
                                  </td>
                                </tr>
                              <% end %>
                            </tbody>
                          </table>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <style>
        .custom-scrollbar::-webkit-scrollbar { width: 6px; }
        .custom-scrollbar::-webkit-scrollbar-track { background: rgba(39,39,42,0.3); border-radius: 3px; }
        .custom-scrollbar::-webkit-scrollbar-thumb { background: rgba(63,63,70,0.8); border-radius: 3px; }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover { background: rgba(82,82,91,1); }
      </style>
    </.sidebar>
    """
  end
end
