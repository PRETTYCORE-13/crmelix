defmodule Prettycore.ArchitectureScanner do
  @moduledoc "Análisis estático específico del proyecto PrettyCore — genera documentación de arquitectura real."

  @source_dirs ~w[lib/prettycore lib/prettycore_web]
  @migration_dirs ~w[priv/psql_repo/migrations priv/repo/migrations]

  # ── Punto de entrada ─────────────────────────────────────────────────────────

  def scan do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
    root = root_dir()

    source_rows    = scan_source_files(root)
    migration_rows = scan_migration_files(root)

    all_rows =
      (source_rows ++ migration_rows)
      |> Enum.with_index(1)
      |> Enum.map(fn {row, idx} -> %{row | id: idx} end)

    %{
      rows:            all_rows,
      funcionalidades: Enum.count(all_rows, &(&1.tipo in ~w[LiveView Controller Context Channel Task Job])),
      tablas:          Enum.count(all_rows, &(&1.tipo in ~w[Schema Migration])),
      timestamp:       timestamp
    }
  end

  # ── Archivos fuente .ex ───────────────────────────────────────────────────────

  defp scan_source_files(root) do
    @source_dirs
    |> Enum.flat_map(fn dir ->
      path = Path.join(root, dir)
      if File.exists?(path), do: Path.wildcard(Path.join(path, "**/*.ex")), else: []
    end)
    |> Enum.flat_map(&analyze_source_file(&1, root))
  end

  defp analyze_source_file(abs_path, root) do
    content  = File.read!(abs_path)
    relative = Path.relative_to(abs_path, root)
    mod      = extract_module_name(content)
    ts       = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")

    # Extracciones ricas
    handle_events  = extract_handle_events(content)
    assigns        = extract_assigns(content)
    context_deps   = extract_context_deps(content)
    public_fns     = extract_public_fns(content)
    schema_fields  = extract_schema_fields(content)

    base = %{
      id:                0,
      modulo:            mod,
      funcionalidad:     "",
      tipo:              "",
      archivo:           relative,
      tabla:             "",
      tabla_relacionada: "",
      tipo_relacion:     "",
      dependencia_de:    context_deps,
      descripcion:       "",
      orden:             0,
      version:           app_version(),
      fecha_scan:        ts
    }

    cond do
      # ── Schema Ecto ──
      Regex.match?(~r/use Ecto\.Schema/, content) ->
        table     = extract_table_name(content) || ""
        relations = extract_relations(content)
        rel_mods  = relations |> Enum.map(& &1.module) |> Enum.uniq() |> Enum.join(", ")
        rel_types = relations |> Enum.map(& &1.type)   |> Enum.uniq() |> Enum.join(", ")
        desc      = build_schema_description(mod, table, schema_fields, relations)

        [%{base |
          funcionalidad:     module_human_name(mod),
          tipo:              "Schema",
          tabla:             table,
          tabla_relacionada: rel_mods,
          tipo_relacion:     rel_types,
          descripcion:       desc}]

      # ── Migration en lib/ ──
      String.contains?(content, "use Ecto.Migration") ->
        table = extract_migration_table(content) || ""
        [%{base |
          funcionalidad: "Migración BD",
          tipo:          "Migration",
          tabla:         table,
          descripcion:   "Migración → tabla `#{table}`"}]

      # ── LiveView ──
      Regex.match?(~r/use \w.*:live_view|use Phoenix\.LiveView/, content) ->
        ops  = if handle_events != [], do: Enum.join(handle_events, ", "), else: "—"
        desc = build_liveview_description(mod, handle_events, assigns)

        [%{base |
          funcionalidad:     module_human_name(mod),
          tipo:              "LiveView",
          tabla_relacionada: context_deps,
          descripcion:       "#{desc} · Operaciones: #{ops}"}]

      # ── Controller ──
      Regex.match?(~r/use \w.*:controller|use Phoenix\.Controller/, content) ->
        actions = extract_actions(content)
        ops     = if actions != [], do: Enum.join(actions, ", "), else: "—"
        [%{base |
          funcionalidad:     module_human_name(mod),
          tipo:              "Controller",
          tabla_relacionada: context_deps,
          descripcion:       "#{build_controller_description(mod)} · Acciones: #{ops}"}]

      # ── Channel ──
      String.contains?(content, "use Phoenix.Channel") ->
        [%{base |
          funcionalidad: module_human_name(mod),
          tipo:          "Channel",
          descripcion:   "Canal WebSocket en tiempo real"}]

      # ── Task Mix ──
      String.contains?(content, "use Mix.Task") ->
        [%{base |
          funcionalidad: module_human_name(mod),
          tipo:          "Task",
          descripcion:   build_task_description(mod, content)}]

      # ── Context / Servicio ──
      String.contains?(relative, "lib/prettycore/") and public_fns != [] ->
        fns_str = public_fns |> Enum.take(8) |> Enum.join(", ")
        [%{base |
          funcionalidad:     module_human_name(mod),
          tipo:              "Context",
          tabla_relacionada: fns_str,
          descripcion:       build_context_description(mod, public_fns)}]

      true -> []
    end
  end

  # ── Migraciones .exs ─────────────────────────────────────────────────────────

  defp scan_migration_files(root) do
    ts = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")

    @migration_dirs
    |> Enum.flat_map(fn dir ->
      path = Path.join(root, dir)
      if File.exists?(path), do: Path.wildcard(Path.join(path, "*.exs")), else: []
    end)
    |> Enum.map(fn abs_path ->
      content  = File.read!(abs_path)
      relative = Path.relative_to(abs_path, root)
      table    = extract_migration_table(content) || ""
      mod      = extract_module_name(content)
      ops      = extract_migration_ops(content)

      %{
        id:                0,
        modulo:            mod,
        funcionalidad:     "Migración BD",
        tipo:              "Migration",
        archivo:           relative,
        tabla:             table,
        tabla_relacionada: "",
        tipo_relacion:     ops,
        dependencia_de:    "",
        descripcion:       build_migration_description(table, content),
        orden:             0,
        version:           app_version(),
        fecha_scan:        ts
      }
    end)
  end

  # ── Constructores de descripción ─────────────────────────────────────────────

  # Descripciones específicas por módulo conocido del negocio
  defp build_liveview_description(mod, events, assigns) do
    basename = module_basename(mod)

    known = %{
      "TiendaLive"           => "Tienda E-commerce · Catálogo de productos con carrito de compras, sincronización de precios desde API REST, secciones dinámicas (Top10, Favoritos, Destacados), filtro por categorías y carrusel de imágenes",
      "Tienda"               => "Tienda E-commerce · Catálogo de productos con carrito de compras, sincronización de precios desde API REST, secciones dinámicas (Top10, Favoritos, Destacados), filtro por categorías y carrusel de imágenes",
      "PedidosLive"          => "Gestión de Pedidos · Órdenes de compra con ciclo de vida: pendiente → procesando → enviado → entregado / cancelado. Admins ven todos los pedidos; usuarios solo los propios",
      "ClientesLive"         => "Gestión de Clientes · Lista de clientes con filtros por UDN/ruta/clasificación, estadísticas (venta anual, cartera, enfriadores), caché 5 min y exportación a Excel",
      "Clientes"             => "Gestión de Clientes · Lista de clientes con filtros por UDN/ruta/clasificación, estadísticas (venta anual, cartera, enfriadores), caché 5 min y exportación a Excel",
      "ClienteFormNewLive"   => "Alta de Cliente · Formulario multi-paso para registro de nuevo cliente con validaciones",
      "ClienteFormEditLive"  => "Edición de Cliente · Formulario multi-paso para actualizar datos de cliente existente",
      "CarruselLive"         => "Carrusel de Imágenes · Administración del carrusel de la tienda: subida a SFTP (JPG/PNG/WebP/GIF, máx 10MB), títulos y vista previa",
      "SeccionesLive"        => "Secciones de Tienda · Activar/desactivar secciones, reordenamiento y edición de nombres en línea (Top10, Favoritos, Destacados, Publicidad)",
      "SeccionEditorLive"    => "Editor de Secciones · Selección de productos específicos para secciones especiales: Top10, Favoritos, Destacados. Búsqueda y filtrado de productos",
      "CategoriasLive"       => "Categorías de Productos · CRUD de categorías con asignación de productos, imágenes y ordenamiento",
      "SuperCategoriasLive"  => "Super Categorías · Agrupaciones de nivel superior: CRUD con descripción, imágenes y asignación de productos",
      "InicioLive"           => "Panel de Inicio · Hub de navegación centralizada del área administrativa",
      "Inicio"               => "Panel de Inicio · Hub de navegación centralizada del área administrativa",
      "ConfiguracionLive"    => "Configuración · Settings de la aplicación: notificaciones, detalles de cuenta, herramientas de sysadmin",
      "ProgramacionLive"     => "Programación · Herramientas de desarrollo: SQL editor, consultas directas a base de datos",
      "WorkOrderLive"        => "Órdenes de Trabajo · Gestión y seguimiento de work orders operativos",
      "LoginLive"            => "Login · Pantalla de autenticación con usuario y contraseña",
      "LoadingLive"          => "Carga Inicial · Pantalla de precarga mientras se inicializa la sesión y se consultan APIs",
      "PasswordResetLive"    => "Recuperar Contraseña · Flujo de reset de contraseña por email",
      "UsersCreateLive"      => "Gestión de Usuarios · Alta y administración de usuarios del sistema con roles y permisos",
      "ClientIntelligenceLive" => "Client Intelligence · Dashboard de analítica de comportamiento de usuarios/clientes",
      "SesionesLive"         => "Sesiones Activas · Monitor de sesiones de usuario activas en el sistema"
    }

    case Map.get(known, basename) do
      nil ->
        # Generar descripción dinámica a partir de assigns y eventos
        data_hints = assigns |> Enum.take(6) |> Enum.join(", ")
        "Pantalla #{humanize(basename)} · Datos: #{data_hints}"

      desc ->
        desc
    end
  end

  defp build_schema_description(mod, table, fields, relations) do
    basename = module_basename(mod)
    rel_count = length(relations)
    fields_str = fields |> Enum.take(8) |> Enum.join(", ")

    known = %{
      "Carrito"         => "Carrito de compras · tabla `#{table}` · estados: activo, completado, cancelado",
      "CarritoItem"     => "Item del carrito · tabla `#{table}` · referencia producto por código (no FK)",
      "Pedido"          => "Pedido/Orden de compra · tabla `#{table}` · estados: pendiente, procesando, enviado, entregado, cancelado · desacoplado de APIs",
      "PedidoItem"      => "Línea de pedido · tabla `#{table}` · precio y descripción denormalizados al momento del pedido",
      "Categoria"       => "Categoría de producto · tabla `#{table}` · con imagen y ordenamiento",
      "SuperCategoria"  => "Super categoría (nivel superior) · tabla `#{table}` · agrupación de categorías",
      "Imagen"          => "Imagen del carrusel · tabla `#{table}` · URL y título",
      "AuthUser"        => "Usuario del sistema · tabla `#{table}` · roles: sysadmin, admin, user · hash Pbkdf2",
      "UserSession"     => "Sesión de usuario · tabla `#{table}` · device_type, browser, OS, last_seen_at",
      "CiEvent"         => "Evento de analítica · tabla `#{table}` · tracking de comportamiento de usuario",
      "CiClientStats"   => "Estadísticas de cliente · tabla `#{table}` · métricas de negocio por cliente",
      "SysConfig"       => "Configuración del sistema · tabla `#{table}` · parámetros de conexión API",
      "Seccion"         => "Sección de tienda · tabla `#{table}` · tipo, nombre, activo, orden",
      "PasswordReset"   => "Token de reset de contraseña · tabla `#{table}` · TTL y uso único"
    }

    base = Map.get(known, basename, "Esquema Ecto · tabla `#{table}`")
    suffix = if fields_str != "", do: " · Campos principales: #{fields_str}", else: ""
    rel_suffix = if rel_count > 0, do: " · #{rel_count} relación(es)", else: ""
    "#{base}#{suffix}#{rel_suffix}"
  end

  defp build_context_description(mod, fns) do
    basename = module_basename(mod)
    fns_str  = fns |> Enum.take(5) |> Enum.join(", ")

    known = %{
      "Carritos"           => "Carrito de compras · Operaciones: agregar/quitar productos, actualizar cantidades, obtener carrito activo del usuario",
      "Pedidos"            => "Pedidos/Órdenes · Ciclo de vida completo: crear desde carrito, listar por rol, cambiar estado, cancelar",
      "Clientes"           => "Integración API Clientes · Estadísticas por cliente: venta anual, cartera, enfriadores, clasificación desde API REST",
      "Categorias"         => "Categorías de productos · CRUD completo con asignación de productos",
      "SuperCategorias"    => "Super categorías · CRUD con descripción e imágenes",
      "Carrusel"           => "Carrusel de imágenes · Alta, listado y eliminación de imágenes para el banner de tienda",
      "Secciones"          => "Secciones de tienda · Gestión de bloques: Top10, Favoritos, Destacados, Publicidad — activo, orden y configuración",
      "Precios"            => "Precios por cliente/dirección · Consulta y sincronización desde API REST, caché en PostgreSQL",
      "Productos"          => "Catálogo de productos · Listado desde API REST con imagen, descripción y código",
      "Auth"               => "Autenticación local · Login, creación de usuarios, cambio de contraseña, reset, gestión de sesiones en PostgreSQL",
      "Catalogos"          => "Catálogos genéricos · Datos auxiliares compartidos entre módulos",
      "CfgMetodopago"      => "Métodos de pago · Configuración de métodos de pago disponibles",
      "SysAdmin"           => "Configuración SysAdmin · Parámetros de conexión API, usuario, instancia, token y URL base",
      "ClientIntelligence" => "Analítica de usuarios · Tracking de eventos, estadísticas de comportamiento y sesiones activas",
      "Encoding"           => "Utilidades de encoding · Conversión Latin1/UTF-8 para compatibilidad con sistemas legacy"
    }

    Map.get(known, basename, "Contexto #{humanize(basename)} · Funciones: #{fns_str}")
  end

  defp build_controller_description(mod) do
    basename = module_basename(mod)

    known = %{
      "SessionController"           => "Control de sesión · Login, logout, creación de sesión con tracking de dispositivo",
      "ClientesExcelController"     => "Exportación Excel de Clientes · Genera .xlsx con filtros de UDN y ruta",
      "ArchitectureExcelController" => "Exportación Excel de Arquitectura · Escaneo estático del proyecto y descarga como .xlsx (solo sysadmin)",
      "HealthController"            => "Health check · Endpoint /health para monitoreo de disponibilidad",
      "SysUdnController"            => "Catálogo de UDNs · API JSON de unidades de negocio",
      "LoginController"             => "Login alternativo · Autenticación de usuario y redirección"
    }

    Map.get(known, basename, "Controlador HTTP #{humanize(basename)}")
  end

  defp build_task_description(mod, content) do
    basename = module_basename(mod)
    short    = case Regex.run(~r/@shortdoc\s+"([^"]+)"/, content) do
                 [_, doc] -> " · #{doc}"
                 _        -> ""
               end
    "Tarea Mix #{humanize(basename)}#{short}"
  end

  defp build_migration_description(table, content) do
    ops = extract_migration_ops(content)
    columns = extract_migration_columns(content) |> Enum.take(6) |> Enum.join(", ")
    col_str = if columns != "", do: " · Columnas: #{columns}", else: ""
    "#{ops} tabla `#{table}`#{col_str}"
  end

  # ── Extracción de código ──────────────────────────────────────────────────────

  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([\w.]+)/, content) do
      [_, name] -> name
      _         -> "—"
    end
  end

  defp extract_table_name(content) do
    case Regex.run(~r/\bschema\s+"([^"]+)"/, content) do
      [_, t] -> t
      _      -> nil
    end
  end

  defp extract_migration_table(content) do
    case Regex.run(~r/(?:create(?:_if_not_exists)?\s+table|alter\s+table)\s*[\(,]\s*:(\w+)/, content) do
      [_, t] -> t
      _ ->
        case Regex.run(~r/(?:create(?:_if_not_exists)?\s+table|alter\s+table)\s*\(\s*"([^"]+)"/, content) do
          [_, t] -> t
          _      -> nil
        end
    end
  end

  defp extract_migration_ops(content) do
    ops = []
    ops = if Regex.match?(~r/create(?:_if_not_exists)?\s+table/, content), do: ["create" | ops], else: ops
    ops = if Regex.match?(~r/alter\s+table/, content), do: ["alter" | ops], else: ops
    ops = if Regex.match?(~r/drop\s+table/, content), do: ["drop" | ops], else: ops
    ops = if Regex.match?(~r/rename\s+table/, content), do: ["rename" | ops], else: ops
    ops = if Regex.match?(~r/add_column|add\s+:/, content), do: ["add_column" | ops], else: ops
    ops = if Regex.match?(~r/create_index|add\s+index/, content), do: ["index" | ops], else: ops
    if ops == [], do: "migración", else: Enum.uniq(ops) |> Enum.join(", ")
  end

  defp extract_migration_columns(content) do
    Regex.scan(~r/add\s+:(\w+),/, content)
    |> Enum.map(fn [_, col] -> col end)
    |> Enum.uniq()
  end

  defp extract_relations(content) do
    Regex.scan(
      ~r/(belongs_to|has_many|has_one|many_to_many)\s+:\w+,\s+([\w.]+)/,
      content
    )
    |> Enum.map(fn [_, type, module] -> %{type: type, module: module} end)
  end

  defp extract_schema_fields(content) do
    Regex.scan(~r/\bfield\s+:(\w+),/, content)
    |> Enum.map(fn [_, f] -> f end)
    |> Enum.reject(&(&1 in ~w[id inserted_at updated_at]))
    |> Enum.uniq()
  end

  defp extract_handle_events(content) do
    Regex.scan(~r/handle_event\("([^"]+)"/, content)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in ~w[change_page toggle_sidebar nav]))
  end

  defp extract_assigns(content) do
    Regex.scan(~r/assign\(socket,\s*:(\w+)/, content)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in ~w[current_page sidebar_open show_programacion_children current_path]))
    |> Enum.take(10)
  end

  defp extract_context_deps(content) do
    # Aliases a módulos del propio dominio (Prettycore.*)
    Regex.scan(~r/alias\s+(Prettycore\.[\w.]+)/, content)
    |> Enum.map(fn [_, mod] -> mod end)
    |> Enum.uniq()
    |> Enum.join(", ")
  end

  defp extract_public_fns(content) do
    skip = ~w[mount render handle_event handle_info handle_params update __using__
              start_link init child_spec call changeset on_mount perform]
    # "def " (espacio literal) NO machea "defp " — funciona con CRLF/LF
    Regex.scan(~r/\bdef (\w+)[\s(]/, content)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in skip))
  end

  defp extract_actions(content) do
    Regex.scan(~r/\bdef (\w+)\(conn,/, content)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
  end

  # ── Helpers de nombre ─────────────────────────────────────────────────────────

  defp module_basename(mod) do
    mod |> String.split(".") |> List.last()
  end

  defp module_human_name(mod) do
    basename = module_basename(mod)

    mapping = %{
      "TiendaLive" => "Tienda E-commerce", "Tienda" => "Tienda E-commerce",
      "PedidosLive" => "Gestión de Pedidos",
      "ClientesLive" => "Gestión de Clientes", "Clientes" => "Gestión de Clientes",
      "ClienteFormNewLive" => "Alta de Cliente",
      "ClienteFormEditLive" => "Edición de Cliente",
      "CarruselLive" => "Carrusel de Imágenes",
      "SeccionesLive" => "Secciones de Tienda",
      "SeccionEditorLive" => "Editor de Secciones",
      "CategoriasLive" => "Categorías de Productos",
      "SuperCategoriasLive" => "Super Categorías",
      "InicioLive" => "Panel de Inicio", "Inicio" => "Panel de Inicio",
      "ConfiguracionLive" => "Configuración",
      "ProgramacionLive" => "Programación / SQL",
      "WorkOrderLive" => "Órdenes de Trabajo",
      "LoginLive" => "Login",
      "LoadingLive" => "Pantalla de Carga",
      "PasswordResetLive" => "Reset de Contraseña",
      "UsersCreateLive" => "Gestión de Usuarios",
      "ClientIntelligenceLive" => "Client Intelligence",
      "SesionesLive" => "Monitor de Sesiones",
      "Carritos" => "Carrito de Compras",
      "Pedidos" => "Pedidos / Órdenes",
      "Clientes" => "Clientes (Contexto)",
      "Categorias" => "Categorías (Contexto)",
      "SuperCategorias" => "Super Categorías (Contexto)",
      "Carrusel" => "Carrusel (Contexto)",
      "Secciones" => "Secciones (Contexto)",
      "Precios" => "Precios por Cliente",
      "Productos" => "Catálogo de Productos",
      "Auth" => "Autenticación",
      "SysAdmin" => "Config SysAdmin",
      "ClientIntelligence" => "Client Intelligence (Contexto)",
      "Carrito" => "Schema: Carrito",
      "CarritoItem" => "Schema: Item de Carrito",
      "Pedido" => "Schema: Pedido",
      "PedidoItem" => "Schema: Línea de Pedido",
      "AuthUser" => "Schema: Usuario",
      "UserSession" => "Schema: Sesión de Usuario",
      "Categoria" => "Schema: Categoría",
      "SuperCategoria" => "Schema: Super Categoría",
      "Imagen" => "Schema: Imagen Carrusel",
      "Seccion" => "Schema: Sección",
      "SessionController" => "Controller: Sesión",
      "ClientesExcelController" => "Controller: Excel Clientes",
      "ArchitectureExcelController" => "Controller: Excel Arquitectura"
    }

    Map.get(mapping, basename, humanize(basename))
  end

  defp humanize(str) do
    str
    |> String.replace(~r/Live$/, "")
    |> String.replace(~r/Controller$/, "")
    |> String.replace("_", " ")
    |> String.replace(~r/([A-Z])/, " \\1")
    |> String.trim()
  end

  defp root_dir, do: File.cwd!()

  defp app_version do
    case Application.spec(:prettycore, :vsn) do
      nil -> "1.0"
      vsn -> to_string(vsn)
    end
  end
end
