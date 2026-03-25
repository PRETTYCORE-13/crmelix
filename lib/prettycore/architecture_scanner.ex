defmodule Prettycore.ArchitectureScanner do
  @moduledoc "Análisis estático del código fuente Phoenix para generar documentación estructural."

  @source_dirs ~w[lib/prettycore lib/prettycore_web]
  @migration_dirs ~w[priv/psql_repo/migrations priv/repo/migrations]

  # ── Punto de entrada ─────────────────────────────────────────────────────────

  def scan do
    timestamp = DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
    root = root_dir()

    source_rows    = scan_source_files(root)
    migration_rows = scan_migration_files(root)

    # Asignar IDs secuenciales (contrato: columna ID empieza en 1)
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

    base = %{
      # ── contrato oficial de 13 columnas ──
      id:               0,          # asignado secuencialmente en el builder
      modulo:           mod,
      funcionalidad:    "",
      tipo:             "",
      archivo:          relative,   # era archivo_origen
      tabla:            "",
      tabla_relacionada: "",
      tipo_relacion:    "",
      dependencia_de:   parent_namespace(mod),  # era flujo_padre
      descripcion:      "",
      orden:            0,
      version:          app_version(),
      fecha_scan:       ts           # era timestamp
    }

    cond do
      # Schema Ecto (prioridad sobre LiveView/Controller)
      Regex.match?(~r/use Ecto\.Schema/, content) ->
        table     = extract_table_name(content) || ""
        relations = extract_relations(content)
        rel_mods  = relations |> Enum.map(& &1.module) |> Enum.uniq() |> Enum.join(", ")
        rel_types = relations |> Enum.map(& &1.type)   |> Enum.uniq() |> Enum.join(", ")
        [%{base | funcionalidad: "Schema", tipo: "Schema",
                  tabla: table, tabla_relacionada: rel_mods, tipo_relacion: rel_types,
                  descripcion: "Esquema Ecto → tabla `#{table}`"}]

      # Migration en lib/ (poco común, pero puede existir)
      String.contains?(content, "use Ecto.Migration") ->
        table = extract_migration_table(content) || ""
        [%{base | funcionalidad: "Migration", tipo: "Migration",
                  tabla: table, descripcion: "Migración → `#{table}`"}]

      # LiveView
      Regex.match?(~r/use \w.*:live_view|use Phoenix\.LiveView/, content) ->
        [%{base | funcionalidad: "LiveView", tipo: "LiveView",
                  descripcion: "Pantalla LiveView"}]

      # Controller
      Regex.match?(~r/use \w.*:controller|use Phoenix\.Controller/, content) ->
        [%{base | funcionalidad: "Controller", tipo: "Controller",
                  descripcion: "Controlador HTTP"}]

      # Channel
      String.contains?(content, "use Phoenix.Channel") ->
        [%{base | funcionalidad: "Channel", tipo: "Channel",
                  descripcion: "Canal WebSocket"}]

      # Task Mix
      String.contains?(content, "use Mix.Task") ->
        [%{base | funcionalidad: "Task", tipo: "Task",
                  descripcion: "Tarea Mix"}]

      # Context (módulo en lib/prettycore/ sin schema/controller/livev)
      String.contains?(relative, "lib/prettycore/") ->
        fns = extract_public_fns(content)
        if fns != [] do
          [%{base | funcionalidad: "Context", tipo: "Context",
                    tabla_relacionada: fns |> Enum.take(6) |> Enum.join(", "),
                    descripcion: "Contexto con #{length(fns)} funciones públicas"}]
        else
          []
        end

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

      %{
        id:               0,
        modulo:           mod,
        funcionalidad:    "Migration",
        tipo:             "Migration",
        archivo:          relative,
        tabla:            table,
        tabla_relacionada: "",
        tipo_relacion:    "",
        dependencia_de:   parent_namespace(mod),
        descripcion:      "Migración → tabla `#{table}`",
        orden:            0,
        version:          app_version(),
        fecha_scan:       ts
      }
    end)
  end

  # ── Extracción ────────────────────────────────────────────────────────────────

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
    # create table(:name), create_if_not_exists table(:name), alter table(:name)
    case Regex.run(~r/(?:create(?:_if_not_exists)?\s+table|alter\s+table)\s*[\(,]\s*:(\w+)/, content) do
      [_, t] -> t
      _ ->
        case Regex.run(~r/(?:create(?:_if_not_exists)?\s+table|alter\s+table)\s*\(\s*"([^"]+)"/, content) do
          [_, t] -> t
          _      -> nil
        end
    end
  end

  defp extract_relations(content) do
    Regex.scan(~r/(belongs_to|has_many|has_one|many_to_many)\s+:\w+,\s+([\w.]+)/, content)
    |> Enum.map(fn [_, type, module] -> %{type: type, module: module} end)
  end

  defp extract_public_fns(content) do
    skip = ~w[mount render handle_event handle_info handle_params update __using__
              start_link init child_spec call changeset]
    Regex.scan(~r/^\s{0,2}def\s+(\w+)[\s\(]/, content, multiline: true)
    |> Enum.map(fn [_, name] -> name end)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in skip))
  end

  defp parent_namespace(mod) do
    parts = String.split(mod, ".")
    if length(parts) > 1, do: Enum.drop(parts, -1) |> Enum.join("."), else: ""
  end

  defp root_dir, do: File.cwd!()

  defp app_version do
    case Application.spec(:prettycore, :vsn) do
      nil -> "1.0"
      vsn -> to_string(vsn)
    end
  end
end
