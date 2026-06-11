defmodule PrettycoreWeb.DisenadorLive do
  use PrettycoreWeb, :live_view_admin

  alias Prettycore.Meta
  alias Prettycore.Meta.{MetaModel, MetaColumn, MetaRelation}
  alias PrettycoreWeb.AdminNav

  @impl true
  def mount(_params, _session, socket) do
    db_esquema = Meta.listar_esquema()
    {:ok,
     socket
     |> assign(:current_page,    "disenador")
     |> assign(:sidebar_open,    false)
     |> assign(:esquema,         db_esquema)
     |> assign(:local_ids,       MapSet.new())
     |> assign(:col_local_ids,   MapSet.new())
     |> assign(:modelo,          nil)
     |> assign(:tab,             :columnas)
     |> assign(:modelo_form,     nil)
     |> assign(:col_form,        nil)
     |> assign(:col_editando_id, nil)
     |> assign(:rel_form,        nil)
     |> assign(:bd_creando,      false)
     |> assign(:bd_mensaje,      nil)
     |> assign(:confirm_rename,  nil)}
  end

  # ── Seleccionar ───────────────────────────────────────────────

  @impl true
  def handle_event("seleccionar", %{"id" => id}, socket) do
    col_local_ids = socket.assigns.col_local_ids
    modelo =
      if local?(id, socket.assigns.local_ids) do
        Enum.find(socket.assigns.esquema, &(&1.id == id))
      else
        db_modelo = Meta.obtener_modelo!(id)
        # Recuperar columnas pendientes guardadas en @esquema para este modelo
        local_pending =
          case Enum.find(socket.assigns.esquema, &(&1.id == id)) do
            nil   -> []
            entry ->
              cols = Map.get(entry, :columnas, [])
              if is_list(cols),
                do: Enum.filter(cols, &MapSet.member?(col_local_ids, &1.id)),
                else: []
          end
        %{db_modelo | columnas: db_modelo.columnas ++ local_pending}
      end
    {:noreply, assign(socket,
      modelo: modelo, modelo_form: nil, col_form: nil, col_editando_id: nil,
      rel_form: nil, tab: :columnas, bd_mensaje: nil)}
  end

  # ── Modelo ────────────────────────────────────────────────────

  def handle_event("nuevo_modelo", _, socket) do
    cs = MetaModel.changeset(%MetaModel{}, %{})
    {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo), modelo: nil)}
  end

  def handle_event("editar_modelo", _, socket) do
    modelo = socket.assigns.modelo
    struct = to_model_struct(modelo)
    cs     = MetaModel.changeset(struct, %{})
    {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo))}
  end

  def handle_event("guardar_modelo", %{"modelo" => attrs}, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids

    cond do
      # Editar modelo ya en DB
      modelo != nil and not local?(modelo.id, local_ids) ->
        nueva_tabla = Map.get(attrs, "tabla_db", "")
        renombra    = modelo.tabla_creada and nueva_tabla != "" and nueva_tabla != modelo.tabla_db

        if renombra do
          cs = MetaModel.changeset(to_model_struct(modelo), attrs)
          if cs.valid? do
            {:noreply, assign(socket,
              confirm_rename: %{old: modelo.tabla_db, new: nueva_tabla, attrs: attrs},
              modelo_form: nil)}
          else
            {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo))}
          end
        else
          case Meta.actualizar_modelo(modelo, attrs) do
            {:ok, m} ->
              m = Meta.obtener_modelo!(m.id)
              {:noreply, assign(socket, esquema: reload_esquema(socket), modelo: m, modelo_form: nil)}
            {:error, cs} ->
              {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo))}
          end
        end

      # Editar modelo local existente
      modelo != nil ->
        cs = MetaModel.changeset(to_model_struct(modelo), attrs)
        if cs.valid? do
          c = Ecto.Changeset.apply_changes(cs)
          nuevo = %{modelo | nombre: c.nombre, descripcion: c.descripcion, tabla_db: c.tabla_db}
          {:noreply, assign(socket,
            esquema: sync_esquema(socket.assigns.esquema, nuevo),
            modelo: nuevo, modelo_form: nil)}
        else
          {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo))}
        end

      # Nuevo modelo local
      true ->
        cs = MetaModel.changeset(%MetaModel{}, attrs)
        if cs.valid? do
          c   = Ecto.Changeset.apply_changes(cs)
          nid = Ecto.UUID.generate()
          nuevo = %{
            id: nid, nombre: c.nombre, descripcion: c.descripcion,
            tabla_db: c.tabla_db, tabla_creada: false,
            columnas: [], endpoints: [], relaciones: []
          }
          {:noreply, assign(socket,
            esquema:   socket.assigns.esquema ++ [nuevo],
            local_ids: MapSet.put(local_ids, nid),
            modelo:    nuevo,
            modelo_form: nil)}
        else
          {:noreply, assign(socket, modelo_form: to_form(cs, as: :modelo))}
        end
    end
  end

  def handle_event("confirmar_renombrar", _, socket) do
    modelo  = socket.assigns.modelo
    confirm = socket.assigns.confirm_rename
    with {:ok, _} <- Meta.renombrar_tabla(modelo, confirm.new),
         {:ok, m} <- Meta.actualizar_modelo(modelo, confirm.attrs) do
      m = Meta.obtener_modelo!(m.id)
      {:noreply, assign(socket,
        modelo:         m,
        esquema:        reload_esquema(socket),
        confirm_rename: nil,
        bd_mensaje:     {:ok, "Tabla renombrada: '#{confirm.old}' → '#{confirm.new}'."})}
    else
      {:error, msg} ->
        {:noreply, assign(socket, confirm_rename: nil, bd_mensaje: {:error, msg})}
    end
  end

  def handle_event("cancelar_renombrar", _, socket) do
    {:noreply, assign(socket, confirm_rename: nil)}
  end

  def handle_event("eliminar_modelo", _, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids
    if local?(modelo.id, local_ids) do
      {:noreply, assign(socket,
        esquema:   Enum.reject(socket.assigns.esquema, &(&1.id == modelo.id)),
        local_ids: MapSet.delete(local_ids, modelo.id),
        modelo: nil, modelo_form: nil)}
    else
      {:ok, _} = Meta.eliminar_modelo(modelo)
      {:noreply, assign(socket, esquema: Meta.listar_esquema(), modelo: nil, modelo_form: nil)}
    end
  end

  def handle_event("crear_tabla_bd", _, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids
    socket    = assign(socket, bd_creando: true, bd_mensaje: nil)

    if local?(modelo.id, local_ids) do
      case Meta.persistir_esquema_local(modelo) do
        {:ok, guardado} ->
          modelo_completo = Meta.obtener_modelo!(guardado.id)
          nuevo_local_ids = MapSet.delete(local_ids, modelo.id)
          db_e    = Meta.listar_esquema()
          local_e = Enum.filter(socket.assigns.esquema, &MapSet.member?(nuevo_local_ids, &1.id))
          {:noreply, assign(socket,
            modelo:    modelo_completo,
            esquema:   db_e ++ local_e,
            local_ids: nuevo_local_ids,
            bd_creando: false,
            bd_mensaje: {:ok, "Tabla '#{modelo_completo.tabla_db}' creada en PostgreSQL."})}

        {:ddl_error, guardado, msg} ->
          modelo_completo = Meta.obtener_modelo!(guardado.id)
          nuevo_local_ids = MapSet.delete(local_ids, modelo.id)
          db_e    = Meta.listar_esquema()
          local_e = Enum.filter(socket.assigns.esquema, &MapSet.member?(nuevo_local_ids, &1.id))
          {:noreply, assign(socket,
            modelo:    modelo_completo,
            esquema:   db_e ++ local_e,
            local_ids: nuevo_local_ids,
            bd_creando: false,
            bd_mensaje: {:error, msg})}

        {:error, msg} ->
          {:noreply, assign(socket, bd_creando: false, bd_mensaje: {:error, msg})}
      end
    else
      case Meta.crear_tabla_en_bd(modelo) do
        {:ok, actualizado} ->
          modelo = Meta.obtener_modelo!(actualizado.id)
          {:noreply, assign(socket,
            modelo:    modelo,
            esquema:   reload_esquema(socket),
            bd_creando: false,
            bd_mensaje: {:ok, "Tabla '#{modelo.tabla_db}' creada en PostgreSQL."})}
        {:error, msg} ->
          {:noreply, assign(socket, bd_creando: false, bd_mensaje: {:error, msg})}
      end
    end
  end

  # ── Tabs ──────────────────────────────────────────────────────

  def handle_event("cambiar_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket,
      tab: String.to_atom(tab), col_form: nil, col_editando_id: nil, rel_form: nil)}
  end

  # ── Columnas ──────────────────────────────────────────────────

  def handle_event("nueva_col", _, socket) do
    cs = MetaColumn.changeset(%MetaColumn{}, %{})
    {:noreply, assign(socket, col_form: to_form(cs, as: :col), col_editando_id: nil)}
  end

  def handle_event("editar_col", %{"id" => id}, socket) do
    modelo        = socket.assigns.modelo
    col_local_ids = socket.assigns.col_local_ids
    col    = Enum.find(modelo.columnas, &(&1.id == id))
    struct = if local?(modelo.id, socket.assigns.local_ids) or MapSet.member?(col_local_ids, id),
               do: to_col_struct(col), else: col
    cs     = MetaColumn.changeset(struct, %{})
    {:noreply, assign(socket, col_form: to_form(cs, as: :col), col_editando_id: id)}
  end

  def handle_event("guardar_col", %{"col" => attrs}, socket) do
    modelo        = socket.assigns.modelo
    local_ids     = socket.assigns.local_ids
    col_local_ids = socket.assigns.col_local_ids
    editing_id    = socket.assigns.col_editando_id
    attrs         = Map.put(attrs, "meta_model_id", modelo.id)

    # Determinar si la columna debe guardarse en memoria:
    # modelo local, o tabla ya creada (cualquier cambio — add o edit — es local)
    col_es_local = local?(modelo.id, local_ids) or modelo.tabla_creada

    if col_es_local do
      cs = MetaColumn.changeset(%MetaColumn{}, attrs)
      if cs.valid? do
        c = Ecto.Changeset.apply_changes(cs)
        build = fn id -> %{
          id: id, meta_model_id: modelo.id,
          nombre: c.nombre, etiqueta: c.etiqueta, tipo: c.tipo,
          longitud: c.longitud, nullable: c.nullable, default_value: c.default_value,
          orden: c.orden, es_pk: c.es_pk, requerido: c.requerido,
          unico: c.unico, min_longitud: c.min_longitud, max_longitud: c.max_longitud
        } end

        {new_cols, new_col_local_ids} =
          if editing_id do
            cols = Enum.map(modelo.columnas, fn col ->
              if col.id == editing_id, do: build.(col.id), else: col
            end)
            # Marcar como pendiente si es modelo DB con tabla creada (nueva o editada)
            new_cids = if modelo.tabla_creada and not local?(modelo.id, local_ids),
              do: MapSet.put(col_local_ids, editing_id), else: col_local_ids
            {cols, new_cids}
          else
            col_id  = Ecto.UUID.generate()
            orden   = length(modelo.columnas)
            new_col = build.(col_id) |> Map.put(:orden, orden)
            new_cids = if modelo.tabla_creada and not local?(modelo.id, local_ids),
              do: MapSet.put(col_local_ids, col_id), else: col_local_ids
            {modelo.columnas ++ [new_col], new_cids}
          end

        nuevo = %{modelo | columnas: new_cols}
        {:noreply, assign(socket,
          modelo:          nuevo,
          esquema:         sync_esquema(socket.assigns.esquema, nuevo),
          col_local_ids:   new_col_local_ids,
          col_form:        nil,
          col_editando_id: nil)}
      else
        {:noreply, assign(socket, col_form: to_form(cs, as: :col))}
      end
    else
      result =
        if editing_id do
          col = Enum.find(modelo.columnas, &(&1.id == editing_id))
          Meta.actualizar_columna(col, attrs)
        else
          Meta.crear_columna(attrs)
        end
      case result do
        {:ok, _} ->
          {:noreply, assign(socket,
            modelo: Meta.obtener_modelo!(modelo.id), col_form: nil, col_editando_id: nil)}
        {:error, cs} ->
          {:noreply, assign(socket, col_form: to_form(cs, as: :col))}
      end
    end
  end

  def handle_event("eliminar_col", %{"id" => id}, socket) do
    modelo        = socket.assigns.modelo
    local_ids     = socket.assigns.local_ids
    col_local_ids = socket.assigns.col_local_ids

    if local?(modelo.id, local_ids) or MapSet.member?(col_local_ids, id) do
      nuevo = %{modelo | columnas: Enum.reject(modelo.columnas, &(&1.id == id))}
      {:noreply, assign(socket,
        modelo:        nuevo,
        esquema:       sync_esquema(socket.assigns.esquema, nuevo),
        col_local_ids: MapSet.delete(col_local_ids, id))}
    else
      col = Enum.find(modelo.columnas, &(&1.id == id))
      {:ok, _} = Meta.eliminar_columna(col)
      {:noreply, assign(socket, modelo: Meta.obtener_modelo!(modelo.id))}
    end
  end

  def handle_event("mover_col", %{"id" => id, "dir" => dir}, socket) do
    modelo        = socket.assigns.modelo
    local_ids     = socket.assigns.local_ids
    col_local_ids = socket.assigns.col_local_ids
    cols          = Enum.sort_by(modelo.columnas, & &1.orden)
    idx           = Enum.find_index(cols, &(&1.id == id))
    target        = if dir == "up", do: idx - 1, else: idx + 1

    if target >= 0 && target < length(cols) do
      reordered =
        cols
        |> List.replace_at(idx,    Enum.at(cols, target))
        |> List.replace_at(target, Enum.at(cols, idx))

      tiene_locales = Enum.any?(modelo.columnas, &MapSet.member?(col_local_ids, &1.id))

      if local?(modelo.id, local_ids) or tiene_locales do
        new_cols = Enum.with_index(reordered, fn c, i -> Map.put(c, :orden, i) end)
        nuevo = %{modelo | columnas: new_cols}
        {:noreply, assign(socket,
          modelo: nuevo, esquema: sync_esquema(socket.assigns.esquema, nuevo))}
      else
        reordered
        |> Enum.with_index()
        |> Enum.each(fn {col, i} ->
          if col.orden != i, do: Meta.actualizar_columna(col, %{"orden" => i})
        end)
        {:noreply, assign(socket, modelo: Meta.obtener_modelo!(modelo.id))}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("agregar_cols_bd", _, socket) do
    modelo        = socket.assigns.modelo
    col_local_ids = socket.assigns.col_local_ids
    pendientes    = Enum.filter(modelo.columnas, &MapSet.member?(col_local_ids, &1.id))

    case Meta.agregar_columnas_a_tabla(modelo, pendientes) do
      {:ok, _} ->
        new_cids = Enum.reduce(pendientes, col_local_ids, fn c, acc -> MapSet.delete(acc, c.id) end)
        {:noreply, assign(socket,
          modelo:        Meta.obtener_modelo!(modelo.id),
          col_local_ids: new_cids,
          bd_mensaje:    {:ok, "#{length(pendientes)} columna(s) agregada(s) a la tabla."})}
      {:error, msg} ->
        {:noreply, assign(socket, bd_mensaje: {:error, msg})}
    end
  end

  # ── Endpoints ─────────────────────────────────────────────────

  def handle_event("toggle_endpoint", %{"operacion" => op}, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids
    existing  = Enum.find(modelo.endpoints, &(&1.operacion == op))

    if local?(modelo.id, local_ids) do
      new_eps =
        if existing do
          Enum.reject(modelo.endpoints, &(&1.operacion == op))
        else
          modelo.endpoints ++ [%{id: Ecto.UUID.generate(), meta_model_id: modelo.id, operacion: op}]
        end
      nuevo = %{modelo | endpoints: new_eps}
      {:noreply, assign(socket,
        modelo: nuevo, esquema: sync_esquema(socket.assigns.esquema, nuevo))}
    else
      if existing, do: Meta.eliminar_endpoint(existing),
                   else: Meta.crear_endpoint(%{meta_model_id: modelo.id, operacion: op})
      {:noreply, assign(socket, modelo: Meta.obtener_modelo!(modelo.id))}
    end
  end

  # ── Relaciones ────────────────────────────────────────────────

  def handle_event("nueva_relacion", _, socket) do
    cs = MetaRelation.changeset(%MetaRelation{}, %{})
    {:noreply, assign(socket, rel_form: to_form(cs, as: :rel))}
  end

  def handle_event("guardar_relacion", %{"rel" => attrs}, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids
    attrs     = Map.put(attrs, "meta_model_id", modelo.id)

    if local?(modelo.id, local_ids) do
      cs = MetaRelation.changeset(%MetaRelation{}, attrs)
      if cs.valid? do
        c = Ecto.Changeset.apply_changes(cs)
        nueva_rel = %{
          id: Ecto.UUID.generate(), meta_model_id: modelo.id,
          tipo: c.tipo, modelo_destino_id: c.modelo_destino_id,
          campo_fk: c.campo_fk, alias: c.alias, destino: nil
        }
        nuevo = %{modelo | relaciones: modelo.relaciones ++ [nueva_rel]}
        {:noreply, assign(socket,
          modelo: nuevo, esquema: sync_esquema(socket.assigns.esquema, nuevo), rel_form: nil)}
      else
        {:noreply, assign(socket, rel_form: to_form(cs, as: :rel))}
      end
    else
      case Meta.crear_relacion(attrs) do
        {:ok, _} ->
          {:noreply, assign(socket, modelo: Meta.obtener_modelo!(modelo.id), rel_form: nil)}
        {:error, cs} ->
          {:noreply, assign(socket, rel_form: to_form(cs, as: :rel))}
      end
    end
  end

  def handle_event("eliminar_relacion", %{"id" => id}, socket) do
    modelo    = socket.assigns.modelo
    local_ids = socket.assigns.local_ids
    if local?(modelo.id, local_ids) do
      nuevo = %{modelo | relaciones: Enum.reject(modelo.relaciones, &(&1.id == id))}
      {:noreply, assign(socket,
        modelo: nuevo, esquema: sync_esquema(socket.assigns.esquema, nuevo))}
    else
      rel = Enum.find(modelo.relaciones, &(&1.id == id))
      {:ok, _} = Meta.eliminar_relacion(rel)
      {:noreply, assign(socket, modelo: Meta.obtener_modelo!(modelo.id))}
    end
  end

  # ── General ───────────────────────────────────────────────────

  def handle_event("cancelar", _, socket) do
    {:noreply, assign(socket,
      modelo_form: nil, col_form: nil, col_editando_id: nil, rel_form: nil)}
  end

  def handle_event("change_page", %{"id" => id}, socket) do
    AdminNav.handle_nav(id, socket, "disenador")
  end

  # ── Helpers del template ──────────────────────────────────────

  defp tab_class(true),  do: "px-4 py-2.5 text-sm border-b-2 border-indigo-500 text-indigo-600 font-medium transition-colors"
  defp tab_class(false), do: "px-4 py-2.5 text-sm border-b-2 border-transparent text-gray-500 hover:text-gray-700 transition-colors"

  defp endpoint_desc("lista"),      do: "GET  /api/dyn/:modelo"
  defp endpoint_desc("show"),       do: "GET  /api/dyn/:modelo/:id"
  defp endpoint_desc("buscar"),     do: "POST /api/dyn/:modelo/buscar"
  defp endpoint_desc("crear"),      do: "POST /api/dyn/:modelo"
  defp endpoint_desc("actualizar"), do: "PUT  /api/dyn/:modelo/:id"
  defp endpoint_desc("eliminar"),   do: "DELETE /api/dyn/:modelo/:id"
  defp endpoint_desc(_),            do: ""

  # ── Helpers privados ──────────────────────────────────────────

  defp local?(id, local_ids), do: MapSet.member?(local_ids, id)

  defp sync_esquema(esquema, modelo) do
    Enum.map(esquema, fn m -> if m.id == modelo.id, do: modelo, else: m end)
  end

  defp reload_esquema(socket) do
    db_e    = Meta.listar_esquema()
    local_e = Enum.filter(socket.assigns.esquema, &MapSet.member?(socket.assigns.local_ids, &1.id))
    db_e ++ local_e
  end

  defp to_model_struct(m) when is_struct(m), do: m
  defp to_model_struct(m) do
    %MetaModel{
      id:           m.id,
      nombre:       m.nombre,
      descripcion:  m.descripcion,
      tabla_db:     m.tabla_db,
      tabla_creada: m.tabla_creada
    }
  end

  defp to_col_struct(c) when is_struct(c), do: c
  defp to_col_struct(c) do
    %MetaColumn{
      id:            c.id,
      meta_model_id: c.meta_model_id,
      nombre:        c.nombre,
      etiqueta:      c.etiqueta,
      tipo:          c.tipo,
      longitud:      c.longitud,
      nullable:      c.nullable,
      default_value: c.default_value,
      orden:         c.orden,
      es_pk:         c.es_pk,
      requerido:     c.requerido,
      unico:         c.unico,
      min_longitud:  c.min_longitud,
      max_longitud:  c.max_longitud
    }
  end
end
