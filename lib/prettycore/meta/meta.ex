defmodule Prettycore.Meta do
  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.Meta.{MetaModel, MetaColumn, MetaEndpoint, MenuSection, MetaRelation}

  # ── MetaModels ────────────────────────────────────────────────

  def listar_esquema do
    PsqlRepo.all(from m in MetaModel, order_by: m.nombre)
  end

  def obtener_modelo!(id) do
    PsqlRepo.get!(MetaModel, id)
    |> PsqlRepo.preload([:columnas, :endpoints, relaciones: :destino])
  end

  def obtener_modelo_por_nombre(nombre) do
    PsqlRepo.get_by(MetaModel, nombre: nombre)
    |> case do
      nil -> nil
      m   -> PsqlRepo.preload(m, [:columnas, :endpoints, relaciones: :destino])
    end
  end

  def crear_modelo(attrs) do
    %MetaModel{}
    |> MetaModel.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def actualizar_modelo(%MetaModel{} = modelo, attrs) do
    modelo
    |> MetaModel.changeset(attrs)
    |> PsqlRepo.update()
  end

  def renombrar_tabla(%MetaModel{} = modelo, nueva_tabla_db) do
    sql = "ALTER TABLE #{modelo.tabla_db} RENAME TO #{nueva_tabla_db}"
    case Ecto.Adapters.SQL.query(PsqlRepo, sql, []) do
      {:ok, _}    -> {:ok, :renamed}
      {:error, e} -> {:error, pg_error(e)}
    end
  end

  def eliminar_modelo(%MetaModel{} = modelo) do
    PsqlRepo.delete(modelo)
  end

  # ── MetaColumns ───────────────────────────────────────────────

  def listar_columnas(meta_model_id) do
    PsqlRepo.all(
      from c in MetaColumn,
      where: c.meta_model_id == ^meta_model_id,
      order_by: c.orden
    )
  end

  def crear_columna(attrs) do
    %MetaColumn{}
    |> MetaColumn.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def actualizar_columna(%MetaColumn{} = col, attrs) do
    col
    |> MetaColumn.changeset(attrs)
    |> PsqlRepo.update()
  end

  def eliminar_columna(%MetaColumn{} = col) do
    PsqlRepo.delete(col)
  end

  # ── MetaEndpoints ─────────────────────────────────────────────

  def listar_endpoints(meta_model_id) do
    PsqlRepo.all(from e in MetaEndpoint, where: e.meta_model_id == ^meta_model_id)
  end

  def crear_endpoint(attrs) do
    %MetaEndpoint{}
    |> MetaEndpoint.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def eliminar_endpoint(%MetaEndpoint{} = ep) do
    PsqlRepo.delete(ep)
  end

  # ── Persistir esquema local y migrar ─────────────────────────

  def persistir_esquema_local(modelo_local) do
    result = PsqlRepo.transaction(fn ->
      m = case crear_modelo(%{
        "nombre"      => modelo_local.nombre,
        "descripcion" => modelo_local.descripcion,
        "tabla_db"    => modelo_local.tabla_db
      }) do
        {:ok, saved}   -> saved
        {:error, cs}   -> PsqlRepo.rollback({:changeset, cs})
      end

      Enum.each(Map.get(modelo_local, :columnas, []), fn col ->
        case crear_columna(col_local_a_attrs(col, m.id)) do
          {:ok, _}     -> :ok
          {:error, cs} -> PsqlRepo.rollback({:changeset, cs})
        end
      end)

      Enum.each(Map.get(modelo_local, :endpoints, []), fn ep ->
        crear_endpoint(%{meta_model_id: m.id, operacion: ep.operacion})
      end)

      m
    end)

    case result do
      {:ok, m} ->
        case crear_tabla_en_bd(m) do
          {:ok, updated}  -> {:ok, updated}
          {:error, msg}   -> {:ddl_error, m, msg}
        end
      {:error, {:changeset, cs}} -> {:error, changeset_error_str(cs)}
      {:error, reason}           -> {:error, inspect(reason)}
    end
  end

  defp col_local_a_attrs(col, model_id) do
    %{
      "meta_model_id" => model_id,
      "nombre"        => to_string(col.nombre || ""),
      "etiqueta"      => to_string(col.etiqueta || ""),
      "tipo"          => to_string(col.tipo || "string"),
      "longitud"      => col.longitud,
      "nullable"      => col.nullable,
      "default_value" => col.default_value,
      "orden"         => col.orden,
      "es_pk"         => col.es_pk,
      "requerido"     => col.requerido,
      "unico"         => col.unico,
      "min_longitud"  => col.min_longitud,
      "max_longitud"  => col.max_longitud
    }
  end

  defp changeset_error_str(cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # ── Agregar columnas a tabla existente (ALTER TABLE) ─────────

  def agregar_columnas_a_tabla(%MetaModel{} = modelo, columnas) do
    Enum.reduce_while(columnas, {:ok, []}, fn col, {:ok, acc} ->
      case PsqlRepo.get(MetaColumn, col.id) do
        nil ->
          # Columna nueva — INSERT + ALTER TABLE ADD COLUMN
          attrs = col_local_a_attrs(col, modelo.id)
          with {:ok, saved} <- crear_columna(attrs) do
            alter = "ALTER TABLE #{modelo.tabla_db} ADD COLUMN IF NOT EXISTS #{columna_a_sql(saved)}"
            case Ecto.Adapters.SQL.query(PsqlRepo, alter, []) do
              {:ok, _}    -> {:cont, {:ok, acc ++ [:added]}}
              {:error, e} -> {:halt, {:error, pg_error(e)}}
            end
          else
            {:error, cs} -> {:halt, {:error, changeset_error_str(cs)}}
          end

        existing ->
          # Columna editada — solo actualizar meta_columns
          attrs = col_local_a_attrs(col, modelo.id)
          case actualizar_columna(existing, attrs) do
            {:ok, _}     -> {:cont, {:ok, acc ++ [:updated]}}
            {:error, cs} -> {:halt, {:error, changeset_error_str(cs)}}
          end
      end
    end)
  end

  defp pg_error(%{postgres: %{message: msg}}), do: msg
  defp pg_error(e), do: inspect(e)

  # ── Crear tabla en BD ─────────────────────────────────────────

  def crear_tabla_en_bd(%MetaModel{} = modelo) do
    columnas = listar_columnas(modelo.id)

    reservados = ~w(id inserted_at updated_at)

    user_cols =
      columnas
      |> Enum.sort_by(& &1.orden)
      |> Enum.reject(&(&1.nombre in reservados))
      |> Enum.map(&columna_a_sql/1)

    all_cols =
      ["id UUID PRIMARY KEY DEFAULT gen_random_uuid()"] ++
      user_cols ++
      ["inserted_at TIMESTAMP NOT NULL DEFAULT NOW()",
       "updated_at  TIMESTAMP NOT NULL DEFAULT NOW()"]

    col_block = Enum.join(all_cols, ",\n  ")

    sql = "CREATE TABLE IF NOT EXISTS #{modelo.tabla_db} (\n  #{col_block}\n)\n"

    case Ecto.Adapters.SQL.query(PsqlRepo, sql, []) do
      {:ok, _} ->
        modelo
        |> MetaModel.status_changeset(%{tabla_creada: true})
        |> PsqlRepo.update()

      {:error, %{postgres: %{message: msg}}} ->
        {:error, msg}

      {:error, err} ->
        {:error, inspect(err)}
    end
  end

  defp columna_a_sql(%MetaColumn{} = c) do
    tipo = tipo_pg(c.tipo, c.longitud)
    null = if c.nullable, do: "", else: " NOT NULL"
    uniq = if c.unico,    do: " UNIQUE", else: ""
    default = if c.default_value, do: " DEFAULT '#{c.default_value}'", else: ""
    "#{c.nombre} #{tipo}#{null}#{uniq}#{default}"
  end

  defp tipo_pg("string",   nil),     do: "VARCHAR(255)"
  defp tipo_pg("string",   len),     do: "VARCHAR(#{len})"
  defp tipo_pg("text",     _),       do: "TEXT"
  defp tipo_pg("integer",  _),       do: "INTEGER"
  defp tipo_pg("float",    _),       do: "NUMERIC"
  defp tipo_pg("boolean",  _),       do: "BOOLEAN"
  defp tipo_pg("date",     _),       do: "DATE"
  defp tipo_pg("datetime", _),       do: "TIMESTAMP"
  defp tipo_pg("uuid",     _),       do: "UUID"
  defp tipo_pg(otro,       _),       do: String.upcase(otro)

  # ── MetaRelations ─────────────────────────────────────────────

  def listar_relaciones(meta_model_id) do
    PsqlRepo.all(
      from r in MetaRelation,
      where: r.meta_model_id == ^meta_model_id,
      preload: [:destino]
    )
  end

  def crear_relacion(attrs) do
    %MetaRelation{}
    |> MetaRelation.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def eliminar_relacion(%MetaRelation{} = rel) do
    PsqlRepo.delete(rel)
  end

  # ── MenuSections ──────────────────────────────────────────────

  def listar_menu do
    PsqlRepo.all(from s in MenuSection, where: s.activo == true, order_by: s.orden)
  end

  def crear_seccion(attrs) do
    %MenuSection{}
    |> MenuSection.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def actualizar_seccion(%MenuSection{} = s, attrs) do
    s
    |> MenuSection.changeset(attrs)
    |> PsqlRepo.update()
  end

  def eliminar_seccion(%MenuSection{} = s) do
    PsqlRepo.delete(s)
  end
end
