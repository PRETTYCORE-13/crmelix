defmodule PrettycoreWeb.SysAdmin.ConfiguracionLive do
  use PrettycoreWeb, :live_view

  import PrettycoreWeb.SysAdminLayout

  alias Prettycore.SysAdmin
  alias Prettycore.Auth

  @api_test_timeout 10_000

  @impl true
  def mount(_params, _session, socket) do
    config = SysAdmin.get_config()

    {:ok,
     socket
     |> assign(:current_page, "configuracion")
     |> assign(:usuario, config.usuario || "")
     |> assign(:instancia, config.instancia || "")
     |> assign(:token, config.token || "")
     |> assign(:url, config.url || "")
     |> assign(:foto, config.foto || "")
     |> assign(:saved, false)
     |> assign(:error, nil)
     |> assign(:show_confirm_modal, false)
     |> assign(:api_test_result, nil)
     |> assign(:api_testing, false)
     |> assign(:pending_params, nil)
     |> assign(:editing_mode, false)
     |> assign(:permitir_edicion, config.permitir_edicion != false)
     |> assign(:arch_scan_status, :idle)
     |> assign(:arch_scan_stats, nil)}
  end

  @impl true
  def handle_event("nav", %{"id" => "configuracion"}, socket) do
    {:noreply, socket}
  end

  # ── Paso 1: interceptar el submit, hacer test de API y mostrar modal ──
  @impl true
  def handle_event("previsualizar", params, socket) do
    url   = String.trim(params["url"]   || "")
    token = String.trim(params["token"] || "")

    if url == "" or token == "" do
      {:noreply, assign(socket, :error, "URL y Token son obligatorios.")}
    else
      test_url = String.trim_trailing(url, "/") <> "/SP/EN_RESTHELPER/SYS_EMPRESA"
      headers  = [
        {"accept",        "application/json"},
        {"content-type",  "application/json"},
        {"authorization", "Bearer #{token}"}
      ]

      api_result =
        case Req.get(test_url, headers: headers, receive_timeout: @api_test_timeout, retry: false) do
          {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
            {:ok, status, body}

          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, status, body}

          {:error, reason} ->
            {:error, :connection, inspect(reason)}
        end

      {:noreply,
       socket
       |> assign(:error, nil)
       |> assign(:show_confirm_modal, true)
       |> assign(:api_test_result, api_result)
       |> assign(:pending_params, params)}
    end
  end

  # ── Paso 2: usuario confirma → guardar de verdad ──
  @impl true
  def handle_event("confirmar_guardar", _, socket) do
    params    = socket.assigns.pending_params
    usuario   = String.trim(params["usuario"]   || "")
    instancia = String.trim(params["instancia"] || "")
    token     = String.trim(params["token"]     || "")
    url       = String.trim(params["url"]       || "")
    foto      = String.trim(params["foto"]      || "")
    password  = String.trim(params["password"]  || "")

    attrs = %{usuario: usuario, instancia: instancia, token: token, url: url, foto: foto,
              permitir_edicion: socket.assigns.permitir_edicion}

    case SysAdmin.save_config(attrs) do
      {:ok, _config} ->
        password_result =
          if password != "" do
            case Auth.get_user_by_username("SYSADMIN") do
              nil  -> {:error, "Usuario SYSADMIN no encontrado"}
              user -> Auth.change_password(user, password)
            end
          else
            :ok
          end

        case password_result do
          res when res in [:ok] or (is_tuple(res) and elem(res, 0) == :ok) ->
            {:noreply,
             socket
             |> assign(:usuario, usuario)
             |> assign(:instancia, instancia)
             |> assign(:token, token)
             |> assign(:url, url)
             |> assign(:foto, foto)
             |> assign(:saved, true)
             |> assign(:error, nil)
             |> assign(:show_confirm_modal, false)
             |> assign(:api_test_result, nil)
             |> assign(:pending_params, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:show_confirm_modal, false)
             |> assign(:error, "Config guardada, pero error al cambiar contraseña: #{inspect(reason)}")}
        end

      {:error, changeset} ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
          |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
          |> Enum.join("; ")

        {:noreply,
         socket
         |> assign(:show_confirm_modal, false)
         |> assign(:error, "Error al guardar: #{errors}")}
    end
  end

  # ── Cancelar modal ──
  @impl true
  def handle_event("cancelar_confirmar", _, socket) do
    {:noreply,
     socket
     |> assign(:show_confirm_modal, false)
     |> assign(:api_test_result, nil)
     |> assign(:pending_params, nil)}
  end

  @impl true
  def handle_event("toggle_editing", _, socket) do
    {:noreply, assign(socket, :editing_mode, !socket.assigns.editing_mode)}
  end

  @impl true
  def handle_event("toggle_permitir_edicion", _, socket) do
    {:noreply, assign(socket, :permitir_edicion, !socket.assigns.permitir_edicion)}
  end

  @impl true
  def handle_event("cancelar_edicion", _, socket) do
    config = SysAdmin.get_config()
    {:noreply,
     socket
     |> assign(:usuario, config.usuario || "")
     |> assign(:instancia, config.instancia || "")
     |> assign(:token, config.token || "")
     |> assign(:url, config.url || "")
     |> assign(:foto, config.foto || "")
     |> assign(:editing_mode, false)
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("dismiss_saved", _, socket) do
    {:noreply, assign(socket, :saved, false)}
  end

  # ── Arquitectura: escaneo + descarga ────────────────────────────────────────

  @impl true
  def handle_event("scan_architecture", _params, socket) do
    # Corre el scanner para obtener estadísticas (el Excel se descarga via HTTP)
    result = Prettycore.ArchitectureScanner.scan()
    stats  = %{funcionalidades: result.funcionalidades, tablas: result.tablas}

    {:noreply,
     socket
     |> assign(:arch_scan_status, :done)
     |> assign(:arch_scan_stats, stats)}
  end

  @impl true
  def handle_event("reset_arch_status", _params, socket) do
    {:noreply, assign(socket, arch_scan_status: :idle, arch_scan_stats: nil)}
  end

  # ── Helpers ──

  defp format_body(body) when is_list(body) or is_map(body) do
    case Jason.encode(body, pretty: true) do
      {:ok, json} -> json
      _           -> inspect(body, pretty: true, limit: 50)
    end
  end
  defp format_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, parsed} -> format_body(parsed)
      _             -> body
    end
  end
  defp format_body(body), do: inspect(body)

  @impl true
  def render(assigns) do
    ~H"""
    <.sidebar current_page={@current_page} current_user_name={@current_user_name}>
      <div class="p-8 max-w-2xl">
        <div class="mb-8">
          <h1 class="text-2xl font-bold text-gray-900">Configuración del sistema</h1>
          <p class="text-sm text-gray-500 mt-1">Ajusta los parámetros de conexión y cuenta.</p>
        </div>

        <%= if @saved do %>
          <div class="mb-6 flex items-center gap-3 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-xl px-4 py-3 text-sm">
            <svg class="w-4 h-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            Configuración guardada correctamente.
            <button type="button" phx-click="dismiss_saved" class="ml-auto text-emerald-600 hover:text-emerald-900">✕</button>
          </div>
        <% end %>

        <%= if @error do %>
          <div class="mb-6 bg-red-50 border border-red-200 text-red-700 rounded-xl px-4 py-3 text-sm">
            {@error}
          </div>
        <% end %>

        <form phx-submit="previsualizar" class="bg-white rounded-2xl border border-gray-200 shadow-sm divide-y divide-gray-100">

          <!-- Toggle: Permitir edición a usuarios normales -->
          <div class="p-5 flex items-center justify-between">
            <div>
              <p class="text-xs font-semibold text-gray-500 uppercase tracking-wide">Editar</p>
              <p class="text-xs text-gray-400 mt-0.5">
                <%= if @permitir_edicion do %>
                  Los usuarios pueden editar clientes.
                <% else %>
                  Los usuarios <strong>no</strong> pueden editar clientes.
                <% end %>
              </p>
            </div>
            <button type="button" phx-click="toggle_permitir_edicion"
              class={"relative inline-flex h-7 w-14 flex-shrink-0 items-center rounded-full transition-colors duration-300 focus:outline-none " <> if @permitir_edicion, do: "bg-emerald-500", else: "bg-gray-300"}>
              <span class={"inline-block h-5 w-5 transform rounded-full bg-white shadow-md transition-transform duration-300 " <> if @permitir_edicion, do: "translate-x-8", else: "translate-x-1"}></span>
              <span class={"absolute text-[10px] font-bold transition-all duration-300 select-none " <> if @permitir_edicion, do: "left-1.5 text-white", else: "right-1.5 text-gray-500"}>
                <%= if @permitir_edicion, do: "SÍ", else: "NO" %>
              </span>
            </button>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Usuario</label>
            <input type="text" name="usuario" value={@usuario} placeholder="Usuario de la API"
              class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">Usuario para autenticación en la API.</p>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Instancia</label>
            <input type="text" name="instancia" value={@instancia} placeholder="https://api.ejemplo.com:1950/SP/EN_RESTHELPER"
              class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">URL base de la API REST.</p>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Token</label>
            <input type="text" name="token" value={@token} placeholder="Bearer token de servicio"
              class="w-full text-sm font-mono rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">Token de autenticación para las llamadas a la API.</p>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">URL</label>
            <input type="text" name="url" value={@url} placeholder="https://ejemplo.com"
              class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">URL pública de la aplicación.</p>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Foto / Logo (URL)</label>
            <input type="text" name="foto" value={@foto} placeholder="https://ejemplo.com/logo.png"
              class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">URL del logotipo de la empresa.</p>
          </div>

          <div class="p-5">
            <label class="block text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">Contraseña</label>
            <input type="password" name="password" value="" placeholder="Dejar vacío para no cambiar"
              class="w-full text-sm rounded-lg border border-gray-300 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-gray-900 focus:border-transparent transition" />
            <p class="mt-1 text-xs text-gray-400">Nueva contraseña del administrador.</p>
          </div>

          <div class="p-5 bg-gray-50 rounded-b-2xl flex justify-end gap-3">
            <button type="button" phx-click="cancelar_edicion"
              class="px-6 py-2 text-sm font-semibold rounded-xl border text-gray-700 bg-white border-gray-300 hover:bg-gray-100 transition-colors">
              Cancelar
            </button>
            <button type="submit"
              class="px-6 py-2 text-sm font-semibold rounded-xl bg-gray-900 text-white hover:bg-black transition-colors">
              Guardar
            </button>
          </div>
        </form>
      </div>

      <!-- ═══════════════════════════════════════ HERRAMIENTAS ADMINISTRATIVAS ═══ -->
      <div class="p-8 max-w-2xl pt-0">
        <div class="border border-gray-200 rounded-2xl bg-white shadow-sm overflow-hidden">
          <div class="px-5 py-4 border-b border-gray-100 flex items-center gap-2">
            <svg class="w-4 h-4 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
              <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
            </svg>
            <h2 class="text-sm font-semibold text-gray-700">Herramientas administrativas</h2>
          </div>

          <div class="p-5 flex items-start justify-between gap-4">
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-800">Generar Excel Arquitectura</p>
              <p class="text-xs text-gray-400 mt-0.5">
                Escanea LiveViews, Controllers, Contexts, Schemas y Migraciones del proyecto.
                Genera un archivo <code class="bg-gray-100 px-1 rounded text-[10px]">.xlsx</code> descargable con la estructura completa.
              </p>
              <%= if @arch_scan_status == :done and @arch_scan_stats do %>
                <div class="mt-2 flex items-center gap-3">
                  <span class="inline-flex items-center gap-1 text-[11px] font-medium text-emerald-700 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
                    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                    <%= @arch_scan_stats.funcionalidades %> funcionalidades
                  </span>
                  <span class="inline-flex items-center gap-1 text-[11px] font-medium text-blue-700 bg-blue-50 border border-blue-200 px-2 py-0.5 rounded-full">
                    <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>
                    <%= @arch_scan_stats.tablas %> tablas
                  </span>
                  <button phx-click="reset_arch_status" class="text-[10px] text-gray-400 hover:text-gray-600 underline">limpiar</button>
                </div>
              <% end %>
            </div>

            <%!-- Enlace de descarga oculto --%>
            <a id="arch-dl-link" href="/sysadmin/architecture-scan" download class="hidden"></a>

            <button
              phx-click={JS.dispatch("click", to: "#arch-dl-link") |> JS.push("scan_architecture")}
              class="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2 bg-gray-900 hover:bg-black text-white text-xs font-semibold rounded-xl transition-colors"
            >
              <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              Generar Excel Arquitectura
            </button>
          </div>
        </div>
      </div>
    </.sidebar>

    <!-- ═══════════════════════════════════════════════════ MODAL CONFIRMACIÓN ═══ -->
    <%= if @show_confirm_modal do %>
      <% api_ok = match?({:ok, _, _}, @api_test_result) %>
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <!-- Backdrop -->
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="cancelar_confirmar"></div>

        <!-- Card -->
        <div class="relative w-full max-w-2xl bg-white rounded-2xl shadow-2xl flex flex-col max-h-[90vh] overflow-hidden">

          <!-- Header -->
          <div class={"flex items-center gap-3 px-6 py-4 border-b " <> if api_ok, do: "bg-emerald-50 border-emerald-200", else: "bg-red-50 border-red-200"}>
            <%= if api_ok do %>
              <div class="w-10 h-10 rounded-full bg-emerald-100 flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <div>
                <p class="font-bold text-emerald-800 text-base">Conexión exitosa</p>
                <p class="text-xs text-emerald-600">La API respondió correctamente. ¿Confirmas guardar la configuración?</p>
              </div>
            <% else %>
              <div class="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
                <svg class="w-5 h-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v4m0 4h.01M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" />
                </svg>
              </div>
              <div>
                <p class="font-bold text-red-800 text-base">Error de conexión</p>
                <p class="text-xs text-red-600">La API no respondió correctamente. Puedes guardar de todas formas, pero revisa los datos.</p>
              </div>
            <% end %>
            <button type="button" phx-click="cancelar_confirmar" class="ml-auto text-gray-400 hover:text-gray-700 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- API Test Result -->
          <div class="px-6 py-4 border-b border-gray-100">
            <div class="flex items-center gap-2 mb-3">
              <span class="text-xs font-bold text-gray-500 uppercase tracking-wider">Respuesta de</span>
              <code class="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded font-mono"><%= String.trim_trailing((@pending_params || %{})["url"] || "", "/") <> "/SP/EN_RESTHELPER/SYS_EMPRESA" %></code>
              <%= case @api_test_result do %>
                <% {:ok, status, _} -> %>
                  <span class="ml-auto text-xs font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-700">HTTP <%= status %></span>
                <% {:error, status, _} when is_integer(status) -> %>
                  <span class="ml-auto text-xs font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700">HTTP <%= status %></span>
                <% {:error, :connection, _} -> %>
                  <span class="ml-auto text-xs font-bold px-2 py-0.5 rounded-full bg-red-100 text-red-700">Sin conexión</span>
                <% _ -> %>
              <% end %>
            </div>

            <div class="bg-gray-950 rounded-xl overflow-auto max-h-64 p-4">
              <pre class="text-xs text-emerald-300 font-mono whitespace-pre-wrap break-all leading-relaxed"><%= case @api_test_result do
                {:ok, _, body}           -> format_body(body)
                {:error, _, body}        -> format_body(body)
                _                        -> "Sin respuesta"
              end %></pre>
            </div>
          </div>

          <!-- Actions -->
          <div class="px-6 py-4 flex items-center justify-end gap-3 bg-gray-50">
            <button type="button" phx-click="cancelar_confirmar"
              class="px-5 py-2 text-sm font-semibold text-gray-700 bg-white border border-gray-300 rounded-xl hover:bg-gray-100 transition-colors">
              Cancelar
            </button>
            <button type="button" phx-click="confirmar_guardar"
              class={"px-5 py-2 text-sm font-semibold text-white rounded-xl transition-colors " <> if api_ok, do: "bg-emerald-600 hover:bg-emerald-700", else: "bg-gray-800 hover:bg-black"}>
              <%= if api_ok, do: "Confirmar y guardar", else: "Guardar de todas formas" %>
            </button>
          </div>

        </div>
      </div>
    <% end %>
    """
  end
end
