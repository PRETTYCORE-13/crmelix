defmodule Prettycore.Secciones do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Secciones.Seccion

  @defaults [
    %{nombre: "Carrusel",             tipo: "carrusel",   orden: 0, activo: true},
    %{nombre: "Tienda",               tipo: "productos",  orden: 1, activo: true},
    %{nombre: "Productos Favoritos",  tipo: "favoritos",  orden: 2, activo: true},
    %{nombre: "Publicidad",           tipo: "publicidad", orden: 3, activo: true},
    %{nombre: "Productos Destacados", tipo: "destacados", orden: 4, activo: true},
    %{nombre: "Envíos",               tipo: "envios",     orden: 5, activo: true},
    %{nombre: "Productos Top 10",     tipo: "top10",      orden: 6, activo: true},
  ]

  def list_secciones do
    all = Repo.all(from s in Seccion, order_by: [asc: s.orden, asc: s.nombre])
    if Enum.empty?(all) do
      seed_defaults()
    else
      existing_tipos = Enum.map(all, & &1.tipo)
      missing = Enum.filter(@defaults, fn d -> d.tipo not in existing_tipos end)
      unless missing == [] do
        max_orden = Enum.max_by(all, & &1.orden).orden
        missing
        |> Enum.with_index(max_orden + 1)
        |> Enum.each(fn {attrs, orden} ->
          %Seccion{} |> Seccion.changeset(Map.put(attrs, :orden, orden)) |> Repo.insert(on_conflict: :nothing)
        end)
        Repo.all(from s in Seccion, order_by: [asc: s.orden, asc: s.nombre])
      else
        all
      end
    end
  end

  def list_activas do
    list_secciones() |> Enum.filter(& &1.activo)
  end

  def seed_defaults do
    Enum.each(@defaults, fn attrs ->
      %Seccion{} |> Seccion.changeset(attrs) |> Repo.insert(on_conflict: :nothing)
    end)
    Repo.all(from s in Seccion, order_by: [asc: s.orden])
  end

  def toggle_activo(%Seccion{} = s) do
    s |> Seccion.changeset(%{activo: not s.activo}) |> Repo.update()
    list_secciones()
  end

  def set_activo(%Seccion{} = s, activo) do
    s |> Seccion.changeset(%{activo: activo}) |> Repo.update()
    list_secciones()
  end

  def update_nombre(%Seccion{} = s, nombre) do
    s |> Seccion.changeset(%{nombre: nombre}) |> Repo.update()
    list_secciones()
  end

  def mover_arriba(%Seccion{} = s) do
    prev = Repo.one(from sec in Seccion, where: sec.orden < ^s.orden, order_by: [desc: sec.orden], limit: 1)
    if prev do
      Repo.update_all(from(sec in Seccion, where: sec.id == ^s.id),    set: [orden: prev.orden])
      Repo.update_all(from(sec in Seccion, where: sec.id == ^prev.id), set: [orden: s.orden])
    end
    list_secciones()
  end

  def mover_abajo(%Seccion{} = s) do
    next = Repo.one(from sec in Seccion, where: sec.orden > ^s.orden, order_by: [asc: sec.orden], limit: 1)
    if next do
      Repo.update_all(from(sec in Seccion, where: sec.id == ^s.id),    set: [orden: next.orden])
      Repo.update_all(from(sec in Seccion, where: sec.id == ^next.id), set: [orden: s.orden])
    end
    list_secciones()
  end

  def reorder(ids) when is_list(ids) do
    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, orden} ->
      Repo.update_all(from(s in Seccion, where: s.id == ^id), set: [orden: orden])
    end)
    list_secciones()
  end

  def create_seccion(attrs) do
    max_orden = Repo.one(from s in Seccion, select: max(s.orden)) || -1
    attrs = Map.put(attrs, "orden", (max_orden + 1))
    %Seccion{} |> Seccion.changeset(attrs) |> Repo.insert()
  end

  def delete_seccion(%Seccion{} = s), do: Repo.delete(s)

  def get_seccion_by_tipo(tipo) do
    Repo.one(from s in Seccion, where: s.tipo == ^tipo)
  end

  def update_config(%Seccion{} = s, config) do
    s |> Seccion.changeset(%{config: config}) |> Repo.update()
  end
end
