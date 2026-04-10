defmodule Prettycore.CategoriasNativas do
  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.CategoriasNativas.CategoriaNativa

  def list_todas, do: PsqlRepo.all(from c in CategoriaNativa, order_by: c.nombre)
  def list_activas, do: PsqlRepo.all(from c in CategoriaNativa, where: c.activo == true, order_by: c.nombre)
  def nombres_activos, do: list_activas() |> Enum.map(& &1.nombre)
  def get(id), do: PsqlRepo.get(CategoriaNativa, id)

  def crear(attrs) do
    %CategoriaNativa{} |> CategoriaNativa.changeset(attrs) |> PsqlRepo.insert()
  end

  def actualizar(%CategoriaNativa{} = c, attrs) do
    c |> CategoriaNativa.changeset(attrs) |> PsqlRepo.update()
  end

  def eliminar(%CategoriaNativa{} = c), do: PsqlRepo.delete(c)
end
