defmodule PrettycoreWeb.Users.UsersCreateLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Auth
  alias Prettycore.Auth.AuthUser

  @impl true
  def mount(_params, _session, socket) do
    changeset = AuthUser.admin_changeset(%AuthUser{}, %{})

    {:ok,
     socket
     |> assign(:current_page, "usuarios")
     |> assign(:sidebar_open, true)
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, false)
     |> assign(:page_title, "Usuarios")
     |> assign(:changeset, changeset)
     |> assign(:form, to_form(changeset))
     |> assign(:users, Auth.list_users())
     |> assign(:show_password, false)
     |> assign(:expanded_permissions_user_id, nil)
     |> assign(:cliente_lookup, nil)}
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "usuarios")
  end

  @impl true
  def handle_event("validate", %{"auth_user" => params}, socket) do
    changeset =
      %AuthUser{}
      |> AuthUser.admin_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"auth_user" => params}, socket) do
    case Auth.create_user_admin(params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Usuario creado exitosamente")
         |> assign(:form, to_form(AuthUser.admin_changeset(%AuthUser{}, %{})))
         |> assign(:users, Auth.list_users())
         |> assign(:cliente_lookup, nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def handle_event("lookup_cliente", %{"auth_user" => %{"cliente_codigo" => codigo}}, socket) do
    codigo = String.trim(codigo)
    result =
      if codigo == "" do
        nil
      else
        case buscar_cliente_en_cache(codigo) do
          nil -> :not_found
          cliente -> {:ok, cliente}
        end
      end
    {:noreply, assign(socket, cliente_lookup: result)}
  end

  def handle_event("lookup_cliente", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_password", _, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  defp buscar_cliente_en_cache(_codigo), do: nil

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    if socket.assigns.user_role != "sysadmin" do
      {:noreply, put_flash(socket, :error, "Solo el sysadmin puede eliminar usuarios.")}
    else
      user = Auth.get_user(id)

      if user do
        case Auth.delete_user(user) do
          {:ok, _} ->
            {:noreply,
             socket
             |> put_flash(:info, "Usuario eliminado")
             |> assign(:users, Auth.list_users())}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Error al eliminar usuario")}
        end
      else
        {:noreply, put_flash(socket, :error, "Usuario no encontrado")}
      end
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
    <div class="min-h-screen bg-white py-10">
      <div class="px-4">
        <!-- Header -->
        <div class="mb-10 text-center">
          <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gray-100 border border-gray-200 mb-4">
            <svg class="w-8 h-8 text-gray-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
            </svg>
          </div>
          <h1 class="text-3xl font-bold text-gray-900">Administrar Usuarios</h1>
          <p class="mt-2 text-gray-500">Crear y gestionar usuarios del sistema</p>
        </div>

        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <!-- Formulario de Crear Usuario -->
          <div class="bg-white border border-gray-200 rounded-2xl p-8 shadow-sm">
            <div class="flex items-center space-x-3 mb-8">
              <div class="w-10 h-10 rounded-xl bg-gray-100 border border-gray-200 flex items-center justify-center">
                <svg class="w-5 h-5 text-gray-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                </svg>
              </div>
              <h2 class="text-xl font-semibold text-gray-900">Crear Nuevo Usuario</h2>
            </div>

            <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">
              <!-- Username -->
              <div>
                <label for="username" class="block text-sm font-medium text-gray-700 mb-2">
                  Usuario <span class="text-purple-500">*</span>
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                  </div>
                  <input
                    type="text"
                    name="auth_user[username]"
                    id="username"
                    value={@form[:username].value}
                    maxlength="50"
                    class={"block w-full pl-10 pr-4 py-3 bg-white border rounded-xl text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all #{if @form[:username].errors != [], do: "border-red-400", else: "border-gray-300"}"}
                    placeholder="nombre_usuario"
                    autocomplete="off"
                  />
                </div>
                <%= if @form[:username].errors != [] do %>
                  <p class="mt-2 text-sm text-red-400 flex items-center">
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                    <%= translate_error(hd(@form[:username].errors)) %>
                  </p>
                <% end %>
              </div>

              <!-- Usuario FROG (hidden, always ROBOOT for client creation) -->
              <input type="hidden" name="auth_user[usuario_frog]" value="ROBOOT" />

              <!-- Cliente + Dirección (2 columnas) -->
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label for="cliente_codigo" class="block text-sm font-medium text-gray-700 mb-2">
                    Código Cliente
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                      </svg>
                    </div>
                    <input
                      type="text"
                      name="auth_user[cliente_codigo]"
                      id="cliente_codigo"
                      value={@form[:cliente_codigo].value}
                      maxlength="20"
                      class="block w-full pl-10 pr-4 py-3 bg-white border border-gray-300 rounded-xl text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all"
                      placeholder="Ej: GN8657B"
                      autocomplete="off"
                    />
                  </div>
                </div>
                <div>
                  <label for="dir_codigo" class="block text-sm font-medium text-gray-700 mb-2">
                    No. Dirección
                  </label>
                  <div class="relative">
                    <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                      <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                    </div>
                    <input
                      type="text"
                      name="auth_user[dir_codigo]"
                      id="dir_codigo"
                      value={@form[:dir_codigo].value}
                      maxlength="10"
                      class="block w-full pl-10 pr-4 py-3 bg-white border border-gray-300 rounded-xl text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all"
                      placeholder="Ej: 1"
                      autocomplete="off"
                    />
                  </div>
                </div>
              </div>

              <!-- Email -->
              <div>
                <label for="email" class="block text-sm font-medium text-gray-700 mb-2">
                  Email <span class="text-purple-500">*</span>
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <input
                    type="email"
                    name="auth_user[email]"
                    id="email"
                    value={@form[:email].value}
                    maxlength="100"
                    class={"block w-full pl-10 pr-4 py-3 bg-white border rounded-xl text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all #{if @form[:email].errors != [], do: "border-red-400", else: "border-gray-300"}"}
                    placeholder="usuario@ejemplo.com"
                    autocomplete="off"
                  />
                </div>
                <%= if @form[:email].errors != [] do %>
                  <p class="mt-2 text-sm text-red-400 flex items-center">
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                    <%= translate_error(hd(@form[:email].errors)) %>
                  </p>
                <% end %>
              </div>

              <!-- Password -->
              <div>
                <label for="password" class="block text-sm font-medium text-gray-700 mb-2">
                  Contrasena <span class="text-purple-500">*</span>
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <svg class="h-5 w-5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                  </div>
                  <input
                    type={if @show_password, do: "text", else: "password"}
                    name="auth_user[password]"
                    id="password"
                    value={@form[:password].value}
                    maxlength="72"
                    class={"block w-full pl-10 pr-12 py-3 bg-white border rounded-xl text-gray-900 placeholder-gray-400 focus:ring-2 focus:ring-purple-600 focus:border-transparent transition-all #{if @form[:password].errors != [], do: "border-red-400", else: "border-gray-300"}"}
                    placeholder="Minimo 6 caracteres"
                    autocomplete="new-password"
                  />
                  <button
                    type="button"
                    phx-click="toggle_password"
                    class="absolute inset-y-0 right-0 flex items-center pr-3 text-gray-400 hover:text-gray-700 transition-colors"
                  >
                    <%= if @show_password do %>
                      <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />
                      </svg>
                    <% else %>
                      <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                      </svg>
                    <% end %>
                  </button>
                </div>
                <%= if @form[:password].errors != [] do %>
                  <p class="mt-2 text-sm text-red-400 flex items-center">
                    <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
                    </svg>
                    <%= translate_error(hd(@form[:password].errors)) %>
                  </p>
                <% end %>
              </div>

              <input type="hidden" name="auth_user[role]" value="user" />

              <input type="hidden" name="auth_user[active]" value="true" />

              <!-- Submit Button -->
              <div class="pt-4">
                <button
                  type="submit"
                  class="w-full flex justify-center items-center py-3.5 px-4 border border-transparent rounded-xl text-sm font-semibold text-white bg-purple-600 hover:bg-purple-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-600 focus:ring-offset-white transition-all duration-200"
                >
                  <svg class="w-5 h-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                  </svg>
                  Crear Usuario
                </button>
              </div>
            </.form>
          </div>

          <!-- Lista de Usuarios -->
          <div class="bg-white border border-gray-200 rounded-2xl p-8 shadow-sm">
            <div class="flex items-center justify-between mb-8">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 rounded-xl bg-gray-100 border border-gray-200 flex items-center justify-center">
                  <svg class="w-5 h-5 text-gray-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
                </div>
                <h2 class="text-xl font-semibold text-gray-900">Usuarios Registrados</h2>
              </div>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-500 border border-gray-200">
                <%= length(@users) %> usuarios
              </span>
            </div>

            <%= if Enum.empty?(@users) do %>
              <div class="text-center py-12">
                <div class="w-16 h-16 rounded-full bg-gray-100 border border-gray-200 flex items-center justify-center mx-auto mb-4">
                  <svg class="w-8 h-8 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z" />
                  </svg>
                </div>
                <p class="text-gray-500">No hay usuarios registrados</p>
                <p class="text-gray-400 text-sm mt-1">Crea el primer usuario usando el formulario</p>
              </div>
            <% else %>
              <div class="space-y-2">
                <%= for user <- Enum.filter(@users, fn u ->
                  cond do
                    @user_role == "oficina" -> u.role == "user"
                    true -> u.role != "sysadmin"
                  end
                end) do %>
                  <% expanded = @expanded_permissions_user_id == user.id %>
                  <% user_perms = user.permissions || ["inicio"] %>
                  <% is_sysadmin_role = user.role == "sysadmin" %>
                  <% is_admin_role = user.role in ["admin", "sysadmin"] %>
                  <div class={"rounded-xl border transition-all duration-200 #{if expanded, do: "border-purple-500/40 bg-purple-50/30", else: "border-gray-200 bg-gray-50/50 hover:bg-gray-50 hover:border-gray-300"}"}>
                    <!-- Fila principal -->
                    <div class="flex items-center justify-between gap-3 p-4">
                      <div class="flex items-center gap-3 min-w-0 flex-1">
                        <div class={"w-12 h-12 shrink-0 rounded-xl flex items-center justify-center text-white font-bold text-lg #{if user.active, do: "bg-purple-600", else: "bg-gray-400"}"}>
                          <%= (String.first(user.username || "?") || "?") |> String.upcase() %>
                        </div>
                        <div class="min-w-0">
                          <p class="text-sm font-semibold text-gray-900 truncate"><%= user.username %></p>
                          <p class="text-xs text-gray-400 mt-0.5 truncate"><%= user.email || "Sin email" %></p>
                          <%= if user.cliente_codigo && user.cliente_codigo != "" do %>
                            <p class="text-xs text-purple-500 mt-0.5 font-mono truncate">
                              <%= user.cliente_codigo %><%= if user.dir_codigo && user.dir_codigo != "", do: " · Dir #{user.dir_codigo}", else: "" %>
                            </p>
                          <% end %>
                        </div>
                      </div>
                      <div class="flex items-center gap-1.5 shrink-0">
                        <span class={"inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-medium #{if user.role == "admin", do: "bg-purple-100 text-purple-600 border border-purple-200", else: "bg-gray-100 text-gray-500 border border-gray-200"}"}>
                          <%= if user.role == "admin" do %>
                            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                              <path fill-rule="evenodd" d="M2.166 4.999A11.954 11.954 0 0010 1.944 11.954 11.954 0 0017.834 5c.11.65.166 1.32.166 2.001 0 5.225-3.34 9.67-8 11.317C5.34 16.67 2 12.225 2 7c0-.682.057-1.35.166-2.001zm11.541 3.708a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                            </svg>
                          <% end %>
                          <%= case user.role do
                            "admin" -> "Administrador"
                            "sysadmin" -> "ECORE"
                            "oficina" -> "Oficina"
                            _ -> "Cliente"
                          end %>
                        </span>
                        <!-- Botón permisos: solo sysadmin puede gestionar -->
                        <%= if @user_role == "sysadmin" and user.role != "user" do %>
                          <button
                            type="button"
                            phx-click="toggle_permissions_panel"
                            phx-value-id={user.id}
                            class={"p-1.5 rounded-lg transition-all duration-200 #{if expanded, do: "text-purple-500 bg-purple-100", else: "text-gray-400 hover:text-purple-500 hover:bg-purple-50"}"}
                            title="Gestionar permisos"
                          >
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                              <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                              <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                            </svg>
                          </button>
                        <% end %>
                        <!-- Botón eliminar: solo sysadmin -->
                        <%= if @user_role == "sysadmin" do %>
                        <button
                          type="button"
                          phx-click="delete_user"
                          phx-value-id={user.id}
                          data-confirm={"¿Eliminar a #{user.username}? Esta acción no se puede deshacer."}
                          class="p-1.5 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all duration-200"
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
                          class={"relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-300 ease-in-out focus:outline-none focus:ring-2 focus:ring-purple-600 focus:ring-offset-2 focus:ring-offset-white #{if user.active, do: "bg-purple-600", else: "bg-gray-300"}"}
                          title={if user.active, do: "Desactivar usuario", else: "Activar usuario"}
                        >
                          <span class={"pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow-lg ring-0 transition duration-300 ease-in-out #{if user.active, do: "translate-x-5", else: "translate-x-0"}"}></span>
                        </button>
                      </div>
                    </div>
                    <!-- Panel de permisos (solo sysadmin) -->
                    <%= if expanded and @user_role == "sysadmin" and user.role != "user" do %>
                      <div class="px-4 pb-4 border-t border-gray-200 pt-3">
                        <table class="w-full text-xs">
                          <thead>
                            <tr>
                              <th class="text-left text-gray-400 font-medium pb-2 pr-4">Página</th>
                              <th class="text-left text-gray-400 font-medium pb-2">Acceso</th>
                            </tr>
                          </thead>
                          <tbody class="divide-y divide-gray-100">
                            <% perms_list = cond do
                            is_sysadmin_role -> [{"categorias", "Categorías Tienda"}, {"editar_imagenes", "Imágenes Tienda"}]
                            user.role == "admin" -> [
                              {"clientes",   "Clientes"},
                              {"tienda",     "Tienda"},
                              {"categorias", "Administrar Tienda"},
                              {"pedidos",    "Ver Pedidos"},
                              {"usuarios",   "Usuarios"}
                            ]
                            user.role == "oficina" -> [{"clientes", "Clientes"}, {"tienda", "Tienda"}, {"categorias", "Administrar Tienda"}, {"pedidos", "Ver Pedidos"}, {"usuarios", "Usuarios"}]
                            true -> [{"tienda", "Tienda"}]
                          end %>
                            <%= for {perm_id, perm_label} <- perms_list do %>
                              <% checked = is_sysadmin_role or perm_id in user_perms %>
                              <% toggle_locked = is_sysadmin_role %>
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
                                      <% "usuarios" -> %>
                                        <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><line x1="19" y1="8" x2="23" y2="8" /><line x1="21" y1="6" x2="21" y2="10" />
                                        </svg>
                                      <% "categorias" -> %>
                                        <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                          <rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" />
                                        </svg>
                                      <% "editar_imagenes" -> %>
                                        <svg class={"w-3.5 h-3.5 #{if checked, do: "text-purple-400", else: "text-zinc-600"}"} fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                                          <path d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z" />
                                          <path d="M15 13a3 3 0 11-6 0 3 3 0 016 0z" />
                                        </svg>
                                      <% _ -> %>
                                    <% end %>
                                    <span class={if checked, do: "text-gray-700", else: "text-gray-400"}><%= perm_label %></span>
                                  </div>
                                </td>
                                <td class="py-2">
                                  <button
                                    type="button"
                                    phx-click={if toggle_locked, do: nil, else: "toggle_permission"}
                                    phx-value-user-id={user.id}
                                    phx-value-permission={perm_id}
                                    disabled={toggle_locked}
                                    class={"relative inline-flex h-5 w-9 flex-shrink-0 rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none #{if checked, do: "bg-purple-600", else: "bg-gray-300"} #{if toggle_locked, do: "opacity-50 cursor-not-allowed", else: "cursor-pointer"}"}
                                    title={if toggle_locked, do: "ECORE tiene acceso completo", else: if(checked, do: "Quitar acceso", else: "Dar acceso")}
                                  >
                                    <span class={"pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow-sm transition duration-200 ease-in-out #{if checked, do: "translate-x-4", else: "translate-x-0"}"}></span>
                                  </button>
                                </td>
                              </tr>
                            <% end %>
                          </tbody>
                        </table>
                        <%= if is_sysadmin_role do %>
                          <p class="text-xs text-gray-400 mt-2 italic">ECORE tiene acceso completo al sistema</p>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Footer -->
        <div class="mt-8 text-center">
          <p class="text-gray-400 text-sm">
            Sistema de gestion de usuarios - PRETTYCORE
          </p>
        </div>
      </div>
    </div>

    <style>
      .custom-scrollbar::-webkit-scrollbar {
        width: 6px;
      }
      .custom-scrollbar::-webkit-scrollbar-track {
        background: rgba(39, 39, 42, 0.3);
        border-radius: 3px;
      }
      .custom-scrollbar::-webkit-scrollbar-thumb {
        background: rgba(63, 63, 70, 0.8);
        border-radius: 3px;
      }
      .custom-scrollbar::-webkit-scrollbar-thumb:hover {
        background: rgba(82, 82, 91, 1);
      }
    </style>
    """
  end
end
