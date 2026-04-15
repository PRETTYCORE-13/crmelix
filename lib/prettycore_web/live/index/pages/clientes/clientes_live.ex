defmodule PrettycoreWeb.Clientes do
  use PrettycoreWeb, :live_view_admin

  import PrettycoreWeb.MenuLayout
  alias Prettycore.Clientes
  alias Prettycore.ClientIntelligence
  import Ecto.Changeset

  # Esquema embedded para los filtros
  defmodule FilterParams do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field :search, :string
      field :sysudn, :string
      field :ruta_desde, :string
      field :ruta_hasta, :string
      field :clasificacion, :string
    end

    def changeset(params, attrs) do
      params
      |> cast(attrs, [:search, :sysudn, :ruta_desde, :ruta_hasta, :clasificacion])
    end
  end

  # Recibimos el :email desde la ruta /admin/clientes
  @impl true
  def mount(_params, _session, socket) do
    alias Prettycore.Api.Client, as: Api
    token = socket.assigns[:frog_token]

    # Invalidar caché si tiene más de 5 minutos (TTL)
    if connected?(socket) do
      last_fetch = :persistent_term.get(:cache_cte_clientes_ts, 0)
      age_ms = System.monotonic_time(:millisecond) - last_fetch
      if age_ms > 300_000 do
        :persistent_term.erase(:cache_cte_clientes)
        :persistent_term.erase(:cache_cte_clientes_ts)
      end
    end

    # Obtener UDNs con caché
    sysudn_opts =
      case :persistent_term.get(:cache_sysudn_opts, nil) do
        nil ->
          opts = case Api.get_all("SYS_USUARIO", token) do
            {:ok, users} ->
              users
              |> Enum.map(& &1["SYSUDN_CODIGO_K"])
              |> Enum.reject(&(&1 in [nil, ""]))
              |> Enum.uniq()
              |> Enum.sort()
            {:error, _} -> []
          end
          if opts != [], do: :persistent_term.put(:cache_sysudn_opts, opts)
          opts
        cached -> cached
      end

    # Obtener rutas con caché
    ruta_opts =
      case :persistent_term.get(:cache_ruta_opts, nil) do
        nil ->
          opts = case Api.get_all("VTA_RUTA", token) do
            {:ok, rutas} ->
              rutas
              |> Enum.map(& &1["VTARUT_CODIGO_K"])
              |> Enum.reject(&(&1 in [nil, ""]))
              |> Enum.uniq()
              |> Enum.sort()
            {:error, _} -> []
          end
          if opts != [], do: :persistent_term.put(:cache_ruta_opts, opts)
          opts
        cached -> cached
      end

    {:ok,
     socket
     |> assign(:current_page, "clientes")
     |> assign(:sidebar_open, true)
     |> assign(:show_programacion_children, false)
     |> assign(:show_clientes_children, true)
     |> assign(:current_path, "/admin/clientes")
     |> assign(:filters_open, false)
     |> assign(:expanded_clients, MapSet.new())
     |> assign(:sysudn_opts, sysudn_opts)
     |> assign(:ruta_opts, ruta_opts)
     |> assign(:stats_modal_open, false)
     |> assign(:stats_modal_ref, nil)
     |> assign(:stats_modal_clasificacion, nil)
     |> assign(:stats_data, nil)
     |> assign(:stats_loading, false)
     |> assign(:stats_clasificaciones, %{})
     |> assign(:reloading, false)
     |> assign(:reload_success, false)
     |> assign(:clasificacion_filter_open, false)
     |> assign(:permitir_edicion, Prettycore.SysAdmin.get_config().permitir_edicion != false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Parsear visible_columns desde los params de la URL
    visible_columns_params =
      params
      |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "visible_columns[") end)
      |> Enum.map(fn {key, value} ->
        column_name = String.replace(key, ~r/visible_columns\[(.*)\]/, "\\1")
        {column_name, value == "true"}
      end)
      |> Enum.into(%{})

    # Columnas visibles desde params o por defecto todas visibles
    # Incluye TODOS los campos de list_clientes_completo para Excel export
    default_visible_columns = %{
      # Campos mostrados en tabla (por defecto visibles)
      "udn" => true,
      "preventa" => true,
      "entrega" => true,
      "autoventa" => true,
      "ctedir_codigo_k" => true,
      "rfc" => true,
      "codigo" => true,
      "razon_social" => true,
      "diascredito" => true,
      "limite_credito" => true,
      "paquete_codigo" => true,
      "frecuencia_codigo" => true,
      "email_receptor" => true,
      "forma_pago" => true,
      "metodo_pago" => true,
      "estatus" => true,
      "nombre_comercial" => true,
      "colonia" => true,
      "map_x" => true,
      "map_y" => true,

      # Campos adicionales de list_clientes_completo (ocultos por defecto)
      "telefono" => false,
      "estado" => false,
      "colonia" => false,
      "calle" => false,
      "ctepfr_codigo_k" => false,
      "frecuencia" => false,
      "canal" => false,
      "subcanal" => false,
      "cadena" => false,
      "paquete_serv" => false,
      "regimen" => false,
      "municipio" => false,
      "localidad" => false,
      "ctedir_callenumext" => false,
      "ctedir_callenumint" => false,
      "ctedir_responsable" => false,
      "ctedir_calleentre1" => false,
      "ctedir_calleentre2" => false,
      "ctedir_cp" => false,
      "ctecli_fechaalta" => false,
      "ctecli_fechabaja" => false,
      "ctecli_causabaja" => false,
      "ctecli_edocred" => false,
      "ctecli_tipodefact" => false,
      "ctecli_tipofacdes" => false,
      "ctecli_tipopago" => false,
      "ctecli_creditoobs" => false,
      "ctetpo_codigo_k" => false,
      "ctesca_codigo_k" => false,
      "ctepaq_codigo_k" => false,
      "ctereg_codigo_k" => false,
      "ctecad_codigo_k" => false,
      "ctecli_generico" => false,
      "cfgmon_codigo_k" => false,
      "ctecli_observaciones" => false,
      "systra_codigo_k" => false,
      "facadd_codigo_k" => false,
      "ctecli_fereceptor" => false,
      "ctepor_codigo_k" => false,
      "ctecli_tipodefacr" => false,
      "condim_codigo_k" => false,
      "ctecli_cxcliq" => false,
      "ctecli_nocta" => false,
      "ctecli_dscantimp" => false,
      "ctecli_desglosaieps" => false,
      "ctecli_periodorefac" => false,
      "ctecli_contacto" => false,
      "cfgban_codigo_k" => false,
      "ctecli_cargaespecifica" => false,
      "ctecli_caducidadmin" => false,
      "ctecli_ctlsanitario" => false,
      "ctecli_regtrib" => false,
      "ctecli_pais" => false,
      "ctecli_factablero" => false,
      "sat_uso_cfdi_k" => false,
      "ctecli_complemento" => false,
      "ctecli_aplicacanje" => false,
      "ctecli_aplicadev" => false,
      "ctecli_desglosakit" => false,
      "faccom_codigo_k" => false,
      "ctecli_facgrupo" => false,
      "facads_codigo_k" => false,
      "s_maqedo" => false,
      "s_fecha" => false,
      "s_fi" => false,
      "s_guid" => false,
      "s_guidlog" => false,
      "s_usuario" => false,
      "s_usuariodb" => false,
      "s_guidnot" => false
    }

    visible_columns = Map.merge(default_visible_columns, visible_columns_params)

    # Crear changeset para el formulario de filtros
    filter_params = %FilterParams{
      search: params["search"],
      sysudn: params["sysudn"],
      ruta_desde: params["ruta_desde"],
      ruta_hasta: params["ruta_hasta"],
      clasificacion: params["clasificacion"]
    }

    filter_form = to_form(FilterParams.changeset(filter_params, %{}))

    # Meta por defecto en caso de error
    default_meta = %Flop.Meta{
      current_page: 1,
      total_pages: 1,
      total_count: 0,
      page_size: 20,
      has_next_page?: false,
      has_previous_page?: false
    }

    # Obtener el token FROG de los assigns
    frog_token = socket.assigns[:frog_token]

    # Cargar clientes con paginación usando Flop
    {clientes, meta, error} =
      try do
        case Clientes.list_clientes_with_flop(params, frog_token) do
          {:ok, {clientes, meta}} -> {clientes, meta, nil}
          {:error, _meta} -> {[], default_meta, "Error al cargar clientes"}
        end
      rescue
        e ->
          require Logger
          Logger.error("Error cargando clientes: #{inspect(e)}")
          {[], default_meta, "Error al cargar clientes. Por favor intenta de nuevo."}
      end

    # Preservar clasificaciones actualizadas por estadísticas (solo stats_modal las modifica)
    # No reconstruir desde CTE_CLIENTES para no sobreescribir valores reales
    existing_stats = socket.assigns[:stats_clasificaciones] || %{}

    was_reloading = socket.assigns[:reloading] == true
    if was_reloading, do: Process.send_after(self(), :clear_reload_success, 3000)

    {:noreply,
     socket
     |> assign(:clientes, clientes)
     |> assign(:meta, meta)
     |> assign(:params, params)
     |> assign(:loading, false)
     |> assign(:error, error)
     |> assign(:visible_columns, visible_columns)
     |> assign(:filter_form, filter_form)
     |> assign(:stats_clasificaciones, existing_stats)
     |> assign(:reloading, false)
     |> assign(:reload_success, was_reloading)}
  end

  ## Handle event para recargar todos los datos de la página
  @impl true
  def handle_event("reload_data", _params, socket) do
    # Limpiar caché de clientes (forzar re-fetch inmediato)
    :persistent_term.erase(:cache_cte_clientes)
    :persistent_term.erase(:cache_cte_clientes_ts)

    # Mostrar spinner primero (separado del patch para que se renderice)
    send(self(), :do_reload)

    {:noreply,
     socket
     |> assign(:reloading, true)
     |> assign(:reload_success, false)
     |> assign(:stats_clasificaciones, %{})}
  end

  @impl true
  def handle_info(:do_reload, socket) do
    query_string = URI.encode_query(flatten_params(socket.assigns.params))
    {:noreply, push_patch(socket, to: "/admin/clientes?#{query_string}")}
  end

  def handle_info(:clear_reload_success, socket) do
    {:noreply, assign(socket, :reload_success, false)}
  end

  ## Handle event para toggle de filtros
  @impl true
  def handle_event("toggle_filters", _params, socket) do
    {:noreply, update(socket, :filters_open, &(not &1))}
  end

  # Prevenir submit del formulario de filtros al presionar Enter
  def handle_event("filter_submit", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_clasificacion_filter", _params, socket) do
    {:noreply, assign(socket, :clasificacion_filter_open, !socket.assigns.clasificacion_filter_open)}
  end

  def handle_event("filter_clasificacion", %{"clasificacion" => clasificacion}, socket) do
    filter_keys = ~w[search sysudn ruta_desde ruta_hasta clasificacion]

    new_params =
      socket.assigns.params
      |> Map.drop(filter_keys)
      |> Map.put("page", "1")
      |> then(fn p ->
        if clasificacion not in [nil, ""],
          do: Map.put(p, "clasificacion", clasificacion),
          else: p
      end)

    query_string = URI.encode_query(flatten_params(new_params))
    {:noreply,
     socket
     |> assign(:clasificacion_filter_open, false)
     |> push_patch(to: "/admin/clientes?#{query_string}")}
  end

  ## Handle event para aplicar filtros (mutuamente excluyentes)
  def handle_event("set_filter", %{"filter_params" => filter_params}, socket) do
    old_params = socket.assigns.params
    filter_keys = ~w[search sysudn ruta_desde ruta_hasta clasificacion]

    # Detectar cuál filtro cambió comparando con los params actuales
    changed_key = Enum.find(filter_keys, fn key ->
      (filter_params[key] || "") != (old_params[key] || "")
    end)

    # Base: quitar todos los filtros de los params existentes
    base_params = Map.drop(old_params, filter_keys) |> Map.put("page", "1")

    # Construir nuevos params: solo con el filtro que cambió (si no está vacío)
    new_params =
      if changed_key && filter_params[changed_key] not in [nil, ""] do
        Map.put(base_params, changed_key, filter_params[changed_key])
      else
        base_params
      end

    # Trackear búsqueda/filtro si hay un valor significativo
    if changed_key && filter_params[changed_key] not in [nil, ""] do
      ClientIntelligence.track_event("*", socket.assigns[:current_user_id], "filtered", %{
        field: changed_key,
        value: filter_params[changed_key]
      })
    end

    query_string = URI.encode_query(flatten_params(new_params))
    {:noreply, push_patch(socket, to: "/admin/clientes?#{query_string}")}
  end

  ## Handle event para expandir/colapsar detalles de cliente
  def handle_event("toggle_client_details", %{"codigo" => codigo, "dir" => dir}, socket) do
    key = "#{codigo}|#{dir}"
    expanded_clients = socket.assigns.expanded_clients

    new_expanded_clients =
      if MapSet.member?(expanded_clients, key) do
        MapSet.delete(expanded_clients, key)
      else
        MapSet.put(expanded_clients, key)
      end

    {:noreply, assign(socket, :expanded_clients, new_expanded_clients)}
  end

  ## Handle event para ver detalles completos del cliente
  def handle_event("show_details", %{"client-id" => client_id}, socket) do
    # Aquí puedes redirigir a una página de detalles o abrir un modal
    # Por ahora solo expandimos la fila
    expanded_rows = MapSet.put(socket.assigns.expanded_rows, client_id)
    {:noreply, assign(socket, :expanded_rows, expanded_rows)}
  end

  ## Handle event para editar cliente
  def handle_event("edit_client", %{"client-id" => client_id}, socket) do
    ClientIntelligence.track_event(client_id, socket.assigns[:current_user_id], "viewed")
    {:noreply, push_navigate(socket, to: ~p"/admin/clientes/edit/#{client_id}")}
  end

  ## Handle event para enviar email al cliente
  def handle_event("send_email", %{"email" => email}, socket) do
    # Aquí puedes implementar la lógica para enviar email
    # Por ejemplo, abrir el cliente de email o un modal de composición
    {:noreply, socket}
  end

  ## Handle event para toggle de columnas
  def handle_event("toggle_column", %{"column" => column}, socket) do
    visible_columns = socket.assigns.visible_columns
    new_visible = Map.update!(visible_columns, column, &(not &1))

    # Actualizar el assign directamente para reflejar cambios inmediatamente
    {:noreply, assign(socket, :visible_columns, new_visible)}
  end

  ## Handle event para seleccionar/deseleccionar todas las columnas
  def handle_event("toggle_all_columns", _params, socket) do
    visible_columns = socket.assigns.visible_columns
    # Si todas están seleccionadas, las deselecciona; si no, las selecciona todas
    all_selected = Enum.all?(visible_columns, fn {_k, v} -> v end)

    new_visible =
      visible_columns
      |> Enum.map(fn {k, _v} -> {k, !all_selected} end)
      |> Enum.into(%{})

    {:noreply, assign(socket, :visible_columns, new_visible)}
  end

  # En tu módulo PrettycoreWeb.Clientes

def handle_event("edit_cliente", %{"codigo" => codigo, "dir" => dir}, socket) do
  ClientIntelligence.track_event(codigo, socket.assigns[:current_user_id], "viewed")
  {:noreply, push_navigate(socket, to: ~p"/admin/clientes/edit/#{codigo}?dir=#{dir}")}

  # O si prefieres abrir un modal:
  # cliente = Clientes.get_cliente_by_codigo(codigo, dir)
  # {:noreply,
  #   socket
  #   |> assign(:editing_cliente, cliente)
  #   |> assign(:show_edit_modal, true)
  # }
end

  ## Handle event para abrir modal de estadísticas
  def handle_event("open_stats_modal", %{"codigo" => codigo, "dir" => dir}, socket) do
    token = socket.assigns[:frog_token]

    # Buscar clasificación del cliente desde CTE_CLIENTES (para el badge del modal)
    cliente_clasificacion =
      socket.assigns[:clientes]
      |> Enum.find(fn c -> c.codigo == codigo end)
      |> case do
        %{clasificacion: c} when is_binary(c) and c != "" -> c
        _ -> nil
      end

    # Abrir modal inmediatamente con loading
    socket =
      socket
      |> assign(:stats_modal_open, true)
      |> assign(:stats_modal_ref, codigo)
      |> assign(:stats_modal_clasificacion, cliente_clasificacion)
      |> assign(:stats_loading, true)
      |> assign(:stats_data, nil)

    # Fetch estadísticas de la API
    case Clientes.get_estadisticas(codigo, dir, token) do
      {:ok, data} ->
        # El badge de la tabla viene de CTE_CLIENTES (cliente.clasificacion), NO de Estadísticas
        # Estadísticas muestra su propia clasificación solo dentro del modal
        {:noreply,
         socket
         |> assign(:stats_data, data)
         |> assign(:stats_loading, false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:stats_data, nil)
         |> assign(:stats_loading, false)}
    end
  end

  # Fallback si no viene dir
  def handle_event("open_stats_modal", %{"codigo" => codigo}, socket) do
    handle_event("open_stats_modal", %{"codigo" => codigo, "dir" => "1"}, socket)
  end

  ## Handle event para cerrar modal de estadísticas
  def handle_event("close_stats_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:stats_modal_open, false)
     |> assign(:stats_modal_ref, nil)
     |> assign(:stats_modal_clasificacion, nil)
     |> assign(:stats_data, nil)
     |> assign(:stats_loading, false)}
  end

  ## Navegación centralizada con CASE (modelo recomendado)
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
        {:noreply, update(socket, :show_clientes_children, &(not &1))}

      "clientes_frog" ->
        {:noreply, socket}

      "tienda" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/tienda")}

      "pedidos" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/pedidos")}

      "categorias" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/categorias")}

      "super_categorias" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/super-categorias")}

      "carrusel" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/carrusel")}

      "secciones" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/secciones")}

      "usuarios" ->
        {:noreply, push_navigate(socket, to: ~p"/admin/usuarios")}

      "toggle_prettycore_children" -> {:noreply, update(socket, :show_prettycore_children, &(not &1))}
      "listas_precios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/listas-precios")}
      "lista_productos"            -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "productos_nativos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/productos-nativos")}
      "clientes_nativos"           -> {:noreply, push_navigate(socket, to: ~p"/admin/clientes-nativos")}
      "stock"                      -> {:noreply, push_navigate(socket, to: ~p"/admin/stock")}
      "sucursales"                 -> {:noreply, push_navigate(socket, to: ~p"/admin/sucursales")}
      "categorias_nativas"         -> {:noreply, push_navigate(socket, to: ~p"/admin/categorias-nativas")}
      "seccion_top10"              -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/top10")}
      "seccion_favoritos"          -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/favoritos")}
      "seccion_destacados"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/destacados")}
      "seccion_ofertas"            -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/ofertas")}
      "seccion_publicidad"         -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/publicidad")}
      "seccion_envios"             -> {:noreply, push_navigate(socket, to: ~p"/admin/seccion/envios")}

      _ ->
        {:noreply, socket}
    end
  end

  ## Helper para verificar si todas las columnas están seleccionadas
  defp all_columns_selected?(visible_columns) do
    Enum.all?(visible_columns, fn {_k, v} -> v end)
  end

  ## Helper para verificar si un cliente está expandido
  defp client_expanded?(expanded_clients, codigo, dir) do
    key = "#{codigo}|#{dir}"
    MapSet.member?(expanded_clients, key)
  end

  ## Helper para obtener la inicial del cliente
  defp get_initial(razon_social) when is_binary(razon_social) do
    trimmed = String.trim(razon_social)
    (String.first(trimmed) || "?") |> String.upcase()
  end
  defp get_initial(_), do: "?"

  ## Helper para obtener color de avatar basado en código
defp avatar_color(codigo) when is_binary(codigo) do
  colors = [
    # Vibrantes
    "bg-purple-500 hover:bg-purple-600 shadow-lg shadow-purple-200",
    "bg-blue-500 hover:bg-blue-600 shadow-lg shadow-blue-200",
    "bg-emerald-500 hover:bg-emerald-600 shadow-lg shadow-emerald-200",
    "bg-amber-500 hover:bg-amber-600 shadow-lg shadow-amber-200",
    "bg-rose-500 hover:bg-rose-600 shadow-lg shadow-rose-200",
    "bg-indigo-500 hover:bg-indigo-600 shadow-lg shadow-indigo-200",
    "bg-cyan-500 hover:bg-cyan-600 shadow-lg shadow-cyan-200",
    "bg-pink-500 hover:bg-pink-600 shadow-lg shadow-pink-200",

    # Pasteles
    "bg-purple-400 hover:bg-purple-500 shadow-lg shadow-purple-100",
    "bg-blue-400 hover:bg-blue-500 shadow-lg shadow-blue-100",
    "bg-emerald-400 hover:bg-emerald-500 shadow-lg shadow-emerald-100"
  ]

  hash = :erlang.phash2(codigo, length(colors))
  Enum.at(colors, hash)
end
  ## Helper para obtener etiqueta de estatus
  defp estatus_label("A"), do: "Activo"
  defp estatus_label("I"), do: "Inactivo"
  defp estatus_label(_), do: "?"

  ## Helper para color del badge de estatus
  defp estatus_badge_class("A"), do: "px-1.5 py-0.5 bg-green-100 text-green-700 rounded text-xs font-medium"
  defp estatus_badge_class("I"), do: "px-1.5 py-0.5 bg-red-100 text-red-700 rounded text-xs font-medium"
  defp estatus_badge_class(_), do: "px-1.5 py-0.5 bg-gray-100 text-gray-700 rounded text-xs font-medium"

  ## Helper para obtener estado de crédito (simulado)
  defp credit_status(_cliente) do
    # Aquí podrías implementar lógica real basada en pagos
    # Por ahora retornamos un valor aleatorio para demostración
    Enum.random(["Al Corriente", "Vencido", "Sin Crédito"])
  end

  ## Helper para color del badge de crédito
  defp credit_badge_class(status) do
    case status do
      "Al Corriente" -> "bg-emerald-500 text-white"
      "Vencido" -> "bg-amber-500 text-white"
      "Sin Crédito" -> "bg-rose-500 text-white"
      _ -> "bg-gray-500 text-white"
    end
  end

  ## Helper para obtener color/estilo de clasificación del cliente
  defp clasificacion_color("ORO"), do: "bg-yellow-400 text-yellow-900"
  defp clasificacion_color("PLATA"), do: "bg-gray-300 text-gray-800"
  defp clasificacion_color("BRONCE"), do: "bg-amber-600 text-white"
  defp clasificacion_color("EXITO"), do: "bg-cyan-400 text-cyan-900"
  defp clasificacion_color("SIN RANGO"), do: "bg-gray-100 text-gray-400"
  defp clasificacion_color(_), do: "bg-gray-200 text-gray-600"

  ## Helper para obtener la imagen de clasificación
  defp clasificacion_imagen("ORO"), do: "https://prettycore.xyz/IMAGENES/LINGOTE.png"
  defp clasificacion_imagen("PLATA"), do: "https://prettycore.xyz/IMAGENES/PLATA.png"
  defp clasificacion_imagen("BRONCE"), do: "https://prettycore.xyz/IMAGENES/BRONCE.png"
  defp clasificacion_imagen("EXITO"), do: "https://prettycore.xyz/IMAGENES/DIAMANTE.png"
  defp clasificacion_imagen(_), do: nil

  ## Helper para formatear números con comas de miles
  defp format_number(value) do
    formatted = :erlang.float_to_binary(value / 1, decimals: 2)
    [int_part, dec_part] = String.split(formatted, ".")
    int_with_commas =
      int_part
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()
    "#{int_with_commas}.#{dec_part}"
  end

  ## Helper para aplanar params anidados
  defp flatten_params(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      case {key, value} do
        {"visible_columns", %{} = nested_map} when is_map(nested_map) ->
          Enum.reduce(nested_map, acc, fn {nested_key, nested_value}, inner_acc ->
            Map.put(inner_acc, "visible_columns[#{nested_key}]", nested_value)
          end)
        _ ->
          Map.put(acc, key, value)
      end
    end)
  end

  ## Funciones helper para paginación (igual que workorder)
  def get_visible_pages(current_page, total_pages, max_visible)
      when is_nil(current_page) or is_nil(total_pages) or total_pages == 0 do
    [1]
  end

  def get_visible_pages(current_page, total_pages, max_visible) do
    cond do
      total_pages <= max_visible ->
        1..total_pages |> Enum.to_list()

      current_page <= div(max_visible, 2) + 1 ->
        1..max_visible |> Enum.to_list()

      current_page >= total_pages - div(max_visible, 2) ->
        (total_pages - max_visible + 1)..total_pages |> Enum.to_list()

      true ->
        start_page = current_page - div(max_visible, 2)
        start_page..(start_page + max_visible - 1) |> Enum.to_list()
    end
  end

  def build_pagination_path(new_params, current_params) do
    merged_params = Map.merge(current_params, new_params)
    flattened_params = flatten_params(merged_params)
    query_string = URI.encode_query(flattened_params)
    "/admin/clientes?#{query_string}"
  end

  ## Helper para construir la URL de descarga de Excel
  def build_excel_download_path(current_params, visible_columns) do
    # Combinar parámetros actuales con columnas visibles
    params_with_columns = Map.merge(current_params, %{
      "visible_columns" => visible_columns
    })

    flattened_params = flatten_params(params_with_columns)
    query_string = URI.encode_query(flattened_params)
    "/admin/clientes/export/excel?#{query_string}"
  end

  ## Render
  @impl true
end
