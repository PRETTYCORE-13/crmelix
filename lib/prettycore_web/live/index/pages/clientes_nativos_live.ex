defmodule PrettycoreWeb.ClientesNativosLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.ClientesNativos
  alias Prettycore.ClientesNativos.ClienteNativo
  alias Prettycore.ListasPrecios
  alias Prettycore.Gamas
  alias Prettycore.Sucursales
  alias Prettycore.Emails.BienvenidaCliente

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_page, "clientes_nativos")
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, false)
     |> assign(:show_prettycore_children, true)
     |> assign(:sidebar_open, true)
     |> assign(:clientes, [])
     |> assign(:search, "")
     |> assign(:modal, nil)
     |> assign(:selected, nil)
     |> assign(:form_nombre, "")
     |> assign(:form_username, "")
     |> assign(:form_email, "")
     |> assign(:form_password, "")
     |> assign(:form_telefono, "")
     |> assign(:form_rfc, "")
     |> assign(:form_direccion, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_lista_precios, 1)
     |> assign(:form_gamas, MapSet.new())
     |> assign(:listas_disponibles, ListasPrecios.numeros_disponibles())
     |> assign(:gamas_disponibles, Gamas.list_gamas())
     |> assign(:sucursales_disponibles, Sucursales.list_activas())
     |> assign(:form_sucursal_numero, nil)
     |> assign(:form_error, nil)
     |> assign(:cambiar_password, false)
     |> load_clientes()}
  end

  defp load_clientes(socket) do
    q = socket.assigns[:search] || ""
    clientes = if q == "", do: ClientesNativos.list_todos(), else: ClientesNativos.search(q)
    assign(socket, :clientes, clientes)
  end

  @impl true
  def handle_event("change_page", %{"id" => id}, socket) do
    PrettycoreWeb.AdminNav.handle_nav(id, socket, "clientes_nativos")
  end

  # ── Búsqueda ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_clientes()}
  end

  @impl true
  def handle_event("search", %{"value" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_clientes()}
  end

  # ── Modales ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("nuevo", _, socket) do
    {:noreply, socket
     |> assign(:modal, :nuevo)
     |> assign(:selected, nil)
     |> assign(:form_nombre, "")
     |> assign(:form_username, "")
     |> assign(:form_email, "")
     |> assign(:form_password, "")
     |> assign(:form_telefono, "")
     |> assign(:form_rfc, "")
     |> assign(:form_direccion, "")
     |> assign(:form_notas, "")
     |> assign(:form_activo, true)
     |> assign(:form_lista_precios, 1)
     |> assign(:form_gamas, MapSet.new())
     |> assign(:form_sucursal_numero, nil)
     |> assign(:form_error, nil)
     |> assign(:cambiar_password, false)}
  end

  @impl true
  def handle_event("editar", %{"id" => id}, socket) do
    case ClientesNativos.get(id) do
      nil -> {:noreply, socket}
      c ->
        gamas_cliente = MapSet.new(ClientesNativos.get_gamas(c.id))
        {:noreply, socket
         |> assign(:modal, :editar)
         |> assign(:selected, c)
         |> assign(:form_nombre, c.nombre)
         |> assign(:form_username, c.username)
         |> assign(:form_email, c.email || "")
         |> assign(:form_password, "")
         |> assign(:form_telefono, c.telefono || "")
         |> assign(:form_rfc, c.rfc || "")
         |> assign(:form_direccion, c.direccion || "")
         |> assign(:form_notas, c.notas || "")
         |> assign(:form_activo, c.activo)
         |> assign(:form_gamas, gamas_cliente)
         |> assign(:form_lista_precios, c.lista_precios || 1)
         |> assign(:form_sucursal_numero, c.sucursal_numero)
         |> assign(:form_error, nil)
         |> assign(:cambiar_password, false)}
    end
  end

  @impl true
  def handle_event("cerrar_modal", _, socket) do
    {:noreply, assign(socket, modal: nil, selected: nil, form_error: nil)}
  end

  @impl true
  def handle_event("toggle_activo_form", _, socket) do
    {:noreply, update(socket, :form_activo, &(not &1))}
  end

  @impl true
  def handle_event("toggle_cambiar_password", _, socket) do
    {:noreply, update(socket, :cambiar_password, &(not &1))}
  end

  # ── Guardar ───────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("guardar", params, socket) do
    nombre        = String.trim(params["nombre"] || "")
    username      = String.trim(params["username"] || "")
    email         = String.trim(params["email"] || "")
    password      = String.trim(params["password"] || "")
    telefono      = String.trim(params["telefono"] || "")
    rfc           = String.trim(params["rfc"] || "")
    direccion     = String.trim(params["direccion"] || "")
    notas         = String.trim(params["notas"] || "")
    activo          = socket.assigns.form_activo
    lista_precios   = parse_int(params["lista_precios"], socket.assigns.form_lista_precios)
    sucursal_numero = parse_int(params["sucursal_numero"], nil)
    gamas_sel = parse_gamas(params["gamas"])

    result =
      case socket.assigns.modal do
        :nuevo ->
          pw_generada = generar_password()
          res = ClientesNativos.crear(%{
            "nombre"          => nombre,
            "username"        => username,
            "email"           => if(email == "", do: nil, else: email),
            "password"        => pw_generada,
            "telefono"        => if(telefono == "", do: nil, else: telefono),
            "rfc"             => if(rfc == "", do: nil, else: rfc),
            "direccion"       => if(direccion == "", do: nil, else: direccion),
            "notas"           => if(notas == "", do: nil, else: notas),
            "activo"          => activo,
            "lista_precios"   => lista_precios,
            "sucursal_numero" => sucursal_numero
          })
          case res do
            {:ok, nuevo_cliente} ->
              ClientesNativos.set_gamas(nuevo_cliente.id, gamas_sel)
              if email != "", do: BienvenidaCliente.send_credenciales(email, nombre, username, pw_generada)
              {:ok, nuevo_cliente}
            err -> err
          end

        :editar ->
          c = socket.assigns.selected
          base_attrs = %{
            "nombre"          => nombre,
            "email"           => if(email == "", do: nil, else: email),
            "telefono"        => if(telefono == "", do: nil, else: telefono),
            "rfc"             => if(rfc == "", do: nil, else: rfc),
            "direccion"       => if(direccion == "", do: nil, else: direccion),
            "notas"           => if(notas == "", do: nil, else: notas),
            "activo"          => activo,
            "lista_precios"   => lista_precios,
            "sucursal_numero" => sucursal_numero
          }

          case ClientesNativos.actualizar(c, base_attrs) do
            {:ok, updated} ->
              ClientesNativos.set_gamas(updated.id, gamas_sel)
              if socket.assigns.cambiar_password and password != "" do
                ClientesNativos.cambiar_password(updated, password)
              else
                {:ok, updated}
              end
            err -> err
          end
      end

    case result do
      {:ok, _} ->
        msg = if socket.assigns.modal == :nuevo, do: "Cliente creado correctamente", else: "Cliente actualizado correctamente"
        {:noreply, socket |> assign(:modal, nil) |> assign(:selected, nil) |> load_clientes() |> put_flash(:info, msg)}

      {:error, changeset} ->
        error = changeset.errors
          |> Enum.map(fn {k, {msg, _}} -> "#{k}: #{msg}" end)
          |> Enum.join(", ")
        {:noreply, assign(socket, :form_error, error)}
    end
  end

  # ── Eliminar ─────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("eliminar", %{"id" => id}, socket) do
    case ClientesNativos.get(id) do
      nil -> {:noreply, socket}
      c ->
        ClientesNativos.eliminar(c)
        {:noreply, load_clientes(socket)}
    end
  end

  # ── Toggle activo rápido ─────────────────────────────────────────────────────

  @impl true
  def handle_event("toggle_activo", %{"id" => id}, socket) do
    case ClientesNativos.get(id) do
      nil -> {:noreply, socket}
      c ->
        ClientesNativos.toggle_activo(c)
        {:noreply, load_clientes(socket)}
    end
  end

  defp generar_password do
    chars = ~c"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#$!"
    len   = length(chars)
    1..12
    |> Enum.map(fn _ -> Enum.at(chars, :rand.uniform(len) - 1) end)
    |> List.to_string()
  end

  defp parse_gamas(nil), do: []
  defp parse_gamas(list) when is_list(list) do
    list |> Enum.map(&parse_int(&1, nil)) |> Enum.reject(&is_nil/1)
  end
  defp parse_gamas(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> [n]
      :error -> []
    end
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default
  defp parse_int(v, _default) when is_integer(v), do: v
  defp parse_int(v, default) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error  -> default
    end
  end

  # ── Render ───────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-3 sm:p-4 space-y-4">
        <!-- Encabezado -->
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="min-w-0">
            <h1 class="text-lg font-bold text-gray-900">Clientes Prettycore</h1>
            <p class="text-xs text-gray-500 hidden sm:block">Clientes registrados directamente en Prettycore</p>
          </div>
          <button
            phx-click="nuevo"
            class="flex items-center gap-2 px-4 py-2 bg-gray-900 hover:bg-gray-700 text-white text-sm font-medium rounded-xl transition-colors flex-shrink-0"
          >
            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
            </svg>
            Nuevo cliente
          </button>
        </div>

        <!-- Buscador -->
        <div class="relative">
          <svg class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
          <input
            type="text"
            placeholder="Buscar por nombre, teléfono o usuario..."
            value={@search}
            phx-keyup="search"
            phx-change="search"
            phx-debounce="300"
            name="q"
            class="w-full pl-9 pr-4 py-2.5 text-sm border border-gray-200 rounded-xl bg-white focus:outline-none focus:ring-2 focus:ring-gray-900/20"
          />
        </div>

        <!-- Tabla -->
        <div class="bg-white rounded-2xl border border-gray-100 overflow-hidden">
          <%= if Enum.empty?(@clientes) do %>
            <div class="py-16 text-center">
              <svg class="w-12 h-12 text-gray-200 mx-auto mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <%= if @search != "" do %>
                <p class="text-sm text-gray-400">Sin resultados para "<%= @search %>"</p>
              <% else %>
                <p class="text-sm text-gray-400">No hay clientes Prettycore aún</p>
              <% end %>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-100 bg-gray-50/50">
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Nombre</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Usuario</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Email</th>
                    <th class="text-left px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Teléfono</th>
                    <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Lista</th>
                    <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Sucursal</th>
                    <th class="text-center px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Estado</th>
                    <th class="text-right px-4 py-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">Acciones</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-50">
                  <%= for c <- @clientes do %>
                    <tr class="hover:bg-gray-50/50 transition-colors">
                      <td class="px-4 py-3">
                        <div class="flex items-center gap-3">
                          <div class="w-8 h-8 rounded-full bg-gray-900 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                            <%= (String.first(c.nombre || "?") || "?") |> String.upcase() %>
                          </div>
                          <div>
                            <p class="font-medium text-gray-900 text-sm"><%= c.nombre %></p>
                            <%= if c.rfc && c.rfc != "" do %>
                              <p class="text-xs text-gray-400">RFC: <%= c.rfc %></p>
                            <% end %>
                          </div>
                        </div>
                      </td>
                      <td class="px-4 py-3">
                        <span class="font-mono text-xs bg-gray-100 px-2 py-0.5 rounded text-gray-700"><%= c.username %></span>
                      </td>
                      <td class="px-4 py-3 text-gray-600 text-xs">
                        <%= if c.email do %>
                          <div class="flex items-center gap-1">
                            <span><%= c.email %></span>
                            <button type="button" data-val={c.email}
                              onclick="navigator.clipboard.writeText(this.dataset.val);this.querySelector('.icon-copy').classList.add('hidden');this.querySelector('.icon-check').classList.remove('hidden');setTimeout(()=>{this.querySelector('.icon-copy').classList.remove('hidden');this.querySelector('.icon-check').classList.add('hidden')},1500)"
                              class="text-gray-400 hover:text-indigo-600 transition-all" title="Copiar email">
                              <svg class="icon-copy w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                              <svg class="icon-check w-3.5 h-3.5 hidden text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                            </button>
                          </div>
                        <% else %>
                          —
                        <% end %>
                      </td>
                      <td class="px-4 py-3 text-gray-600 text-xs">
                        <%= if c.telefono do %>
                          <div class="flex items-center gap-1">
                            <span><%= c.telefono %></span>
                            <button type="button" data-val={c.telefono}
                              onclick="navigator.clipboard.writeText(this.dataset.val);this.querySelector('.icon-copy').classList.add('hidden');this.querySelector('.icon-check').classList.remove('hidden');setTimeout(()=>{this.querySelector('.icon-copy').classList.remove('hidden');this.querySelector('.icon-check').classList.add('hidden')},1500)"
                              class="text-gray-400 hover:text-indigo-600 transition-all" title="Copiar teléfono">
                              <svg class="icon-copy w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
                              <svg class="icon-check w-3.5 h-3.5 hidden text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                            </button>
                          </div>
                        <% else %>
                          —
                        <% end %>
                      </td>
                      <td class="px-4 py-3 text-center">
                        <span class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-gray-100 text-gray-600">
                          L<%= c.lista_precios || 1 %>
                        </span>
                      </td>
                      <td class="px-4 py-3 text-center text-xs text-gray-500">
                        <%= if c.sucursal_numero do %>
                          <%= Enum.find_value(@sucursales_disponibles, "Suc. #{c.sucursal_numero}", fn s -> if s.numero == c.sucursal_numero, do: s.nombre end) || "—" %>
                        <% else %>
                          —
                        <% end %>
                      </td>
                      <td class="px-4 py-3 text-center">
                        <button phx-click="toggle_activo" phx-value-id={c.id}
                          class={"inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold cursor-pointer transition-colors #{if c.activo, do: "bg-green-100 text-green-700 hover:bg-green-200", else: "bg-gray-100 text-gray-500 hover:bg-gray-200"}"}>
                          <%= if c.activo, do: "Activo", else: "Inactivo" %>
                        </button>
                      </td>
                      <td class="px-4 py-3">
                        <div class="flex items-center justify-end gap-2">
                          <button phx-click="editar" phx-value-id={c.id}
                            class="p-1.5 text-gray-400 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors" title="Editar">
                            <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                            </svg>
                          </button>
                          <button phx-click="toggle_activo" phx-value-id={c.id}
                            data-confirm={if c.activo, do: "¿Inactivar a #{c.nombre}?", else: "¿Activar a #{c.nombre}?"}
                            class={"p-1.5 rounded-lg transition-colors #{if c.activo, do: "text-green-500 hover:text-red-500 hover:bg-red-50", else: "text-red-500 hover:text-green-600 hover:bg-green-50"}"}
                            title={if c.activo, do: "Inactivar cliente", else: "Activar cliente"}>
                            <%= if c.activo do %>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                              </svg>
                            <% else %>
                              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                              </svg>
                            <% end %>
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>

        <!-- Contador -->
        <p class="text-xs text-gray-400 text-right"><%= length(@clientes) %> cliente(s)</p>
      </div>

      <!-- ══ MODAL ══ -->
      <%= if @modal in [:nuevo, :editar] do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm">
          <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <!-- Header modal -->
            <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
              <h2 class="font-bold text-gray-900">
                <%= if @modal == :nuevo, do: "Nuevo Cliente", else: "Editar Cliente" %>
              </h2>
              <button phx-click="cerrar_modal" class="p-1.5 hover:bg-gray-100 rounded-lg transition-colors">
                <svg class="w-5 h-5 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Form -->
            <form phx-submit="guardar" class="px-6 py-5 space-y-4">
              <!-- Error -->
              <%= if @form_error do %>
                <div class="bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl px-4 py-2">
                  <%= @form_error %>
                </div>
              <% end %>

              <!-- Nombre -->
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">Nombre completo *</label>
                <input type="text" name="nombre" value={@form_nombre} required
                  maxlength="150"
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                  placeholder="Nombre del cliente" />
              </div>

              <!-- Username -->
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">
                  Usuario (para iniciar sesión) *
                </label>
                <input type="text" name="username" value={@form_username}
                  required={@modal == :nuevo}
                  readonly={@modal == :editar}
                  autocomplete="off"
                  maxlength="50"
                  class={"w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20 #{if @modal == :editar, do: "bg-gray-50 text-gray-400"}"}
                  placeholder="Nombre de usuario para inicio de sesión" />
                <div class="mt-1.5 flex items-center gap-1.5">
                  <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-blue-50 border border-blue-100 text-blue-600 text-[10px] font-semibold">
                    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                    Tipo: Cliente
                  </span>
                  <span class="text-[10px] text-gray-400">Solo acceso a la tienda</span>
                </div>
                <%= if @modal == :editar do %>
                  <p class="text-xs text-gray-400 mt-0.5">El usuario no se puede cambiar</p>
                <% end %>
              </div>

              <!-- Email y Teléfono en fila -->
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">Email *</label>
                  <input type="email" name="email" value={@form_email}
                    maxlength="100" required
                    class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                    placeholder="correo@ejemplo.com" />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">Teléfono *</label>
                  <input type="text" name="telefono" value={@form_telefono}
                    maxlength="20" required
                    class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                    placeholder="10 dígitos" />
                </div>
              </div>

              <!-- RFC y Lista de Precios -->
              <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">RFC</label>
                  <input type="text" name="rfc" value={@form_rfc}
                    maxlength="20"
                    class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                    placeholder="RFC del cliente" />
                </div>
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">Lista de precios *</label>
                  <%= if @listas_disponibles == [] do %>
                    <div class="w-full px-3 py-2 text-xs border border-dashed border-gray-200 rounded-xl text-gray-400 bg-gray-50">
                      Sin listas creadas aún
                    </div>
                    <input type="hidden" name="lista_precios" value={@form_lista_precios} />
                  <% else %>
                    <select name="lista_precios"
                      class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20 bg-white">
                      <%= for n <- @listas_disponibles do %>
                        <option value={n} selected={n == @form_lista_precios}>Lista <%= n %></option>
                      <% end %>
                    </select>
                  <% end %>
                  <p class="text-[10px] text-gray-400 mt-0.5">Asigna qué lista de precios verá este cliente</p>
                </div>

                <div class="sm:col-span-2">
                  <label class="block text-xs font-semibold text-gray-700 mb-1">Gamas de productos</label>
                  <%= if @gamas_disponibles == [] do %>
                    <div class="w-full px-3 py-2 text-xs border border-dashed border-gray-200 rounded-xl text-gray-400 bg-gray-50">
                      Sin gamas creadas aún
                    </div>
                  <% else %>
                    <div class="grid grid-cols-2 gap-1.5 p-2 border border-gray-200 rounded-xl bg-gray-50/50">
                      <%= for g <- @gamas_disponibles do %>
                        <label class="flex items-center gap-2 px-2 py-1.5 rounded-lg cursor-pointer hover:bg-white transition-colors">
                          <input type="checkbox" name="gamas[]" value={g.numero}
                            checked={MapSet.member?(@form_gamas, g.numero)}
                            class="rounded border-gray-300 text-purple-600 focus:ring-purple-500" />
                          <span class="text-xs font-medium text-gray-700">
                            <span class="text-gray-400 font-mono">G<%= g.numero %></span>
                            <%= if g.nombre && g.nombre != "", do: " · #{g.nombre}", else: "" %>
                          </span>
                        </label>
                      <% end %>
                    </div>
                  <% end %>
                  <p class="text-[10px] text-gray-400 mt-0.5">El cliente verá solo productos de las gamas seleccionadas</p>
                </div>

                <!-- Sucursal -->
                <div>
                  <label class="block text-xs font-semibold text-gray-700 mb-1">Sucursal *</label>
                  <%= if @sucursales_disponibles == [] do %>
                    <div class="text-xs text-gray-400 px-3 py-2 border border-gray-200 rounded-xl">
                      Sin sucursales creadas
                    </div>
                    <input type="hidden" name="sucursal_numero" value="" />
                  <% else %>
                    <select name="sucursal_numero"
                      class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20 bg-white">
                      <option value="">— Sin sucursal —</option>
                      <%= for s <- @sucursales_disponibles do %>
                        <option value={s.numero} selected={s.numero == @form_sucursal_numero}><%= s.numero %> – <%= s.nombre %></option>
                      <% end %>
                    </select>
                  <% end %>
                  <p class="text-[10px] text-gray-400 mt-0.5">Sucursal a la que pertenece este cliente</p>
                </div>
              </div>
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">Dirección *</label>
                <input type="text" name="direccion" value={@form_direccion}
                  maxlength="300" required
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                  placeholder="Dirección completa" />
              </div>

              <!-- Notas -->
              <div>
                <label class="block text-xs font-semibold text-gray-700 mb-1">Notas</label>
                <textarea name="notas" rows="2"
                  maxlength="500"
                  class="w-full px-3 py-2 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20 resize-none"
                  placeholder="Notas internas..."><%= @form_notas %></textarea>
              </div>

              <!-- Password -->
              <%= if @modal == :nuevo do %>
                <div class="flex items-start gap-3 bg-indigo-50 border border-indigo-100 rounded-xl px-4 py-3">
                  <svg class="w-4 h-4 text-indigo-500 flex-shrink-0 mt-0.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <p class="text-xs text-indigo-700 leading-relaxed">
                    Se generará una contraseña segura automáticamente y se enviará al correo del cliente.
                  </p>
                </div>
              <% else %>
                <div class="border border-gray-100 rounded-xl p-3">
                  <div class="flex items-center justify-between">
                    <span class="text-xs font-semibold text-gray-700">Cambiar contraseña</span>
                    <button type="button" phx-click="toggle_cambiar_password"
                      class={"relative inline-flex h-5 w-9 items-center rounded-full transition-colors #{if @cambiar_password, do: "bg-gray-900", else: "bg-gray-200"}"}>
                      <span class={"inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform #{if @cambiar_password, do: "translate-x-4", else: "translate-x-1"}"} />
                    </button>
                  </div>
                  <%= if @cambiar_password do %>
                    <div class="mt-2 relative">
                      <input id="pw_edit" type="password" name="password" value=""
                        autocomplete="new-password"
                        maxlength="72"
                        class="w-full px-3 py-2 pr-10 text-sm border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                        placeholder="Nueva contraseña (mín. 6 caracteres)" />
                      <button type="button" tabindex="-1"
                        onclick="var i=document.getElementById('pw_edit');i.type=i.type==='password'?'text':'password';this.querySelector('.eye-off').classList.toggle('hidden');this.querySelector('.eye-on').classList.toggle('hidden')"
                        class="absolute right-2.5 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-700 transition-colors">
                        <svg class="eye-on w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>
                        <svg class="eye-off w-4 h-4 hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/></svg>
                      </button>
                    </div>
                  <% else %>
                    <input type="hidden" name="password" value="" />
                  <% end %>
                </div>
              <% end %>

              <!-- Activo toggle -->
              <div class="flex items-center justify-between py-2 border-t border-gray-100">
                <span class="text-xs font-semibold text-gray-700">Cliente activo</span>
                <button type="button" phx-click="toggle_activo_form"
                  class={"relative inline-flex h-5 w-9 items-center rounded-full transition-colors #{if @form_activo, do: "bg-green-500", else: "bg-gray-200"}"}>
                  <span class={"inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform #{if @form_activo, do: "translate-x-4", else: "translate-x-1"}"} />
                </button>
              </div>

              <!-- Botones -->
              <div class="flex gap-3 pt-2">
                <button type="button" phx-click="cerrar_modal"
                  class="flex-1 py-2.5 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-xl transition-colors">
                  Cancelar
                </button>
                <button type="submit"
                  class="flex-1 py-2.5 text-sm font-semibold text-white bg-gray-900 hover:bg-gray-700 rounded-xl transition-colors">
                  <%= if @modal == :nuevo, do: "Crear cliente", else: "Guardar cambios" %>
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    """
  end
end
