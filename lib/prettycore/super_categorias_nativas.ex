defmodule Prettycore.SuperCategoriasNativas do
  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.SuperCategoriasNativas.SuperCategoriaNativa

  def list_todas, do: PsqlRepo.all(from c in SuperCategoriaNativa, order_by: c.nombre)
  def list_activas, do: PsqlRepo.all(from c in SuperCategoriaNativa, where: c.activo == true, order_by: c.nombre)
  def nombres_activos, do: list_activas() |> Enum.map(& &1.nombre)
  def get(id), do: PsqlRepo.get(SuperCategoriaNativa, id)

  def crear(attrs) do
    %SuperCategoriaNativa{} |> SuperCategoriaNativa.changeset(attrs) |> PsqlRepo.insert()
  end

  def actualizar(%SuperCategoriaNativa{} = sc, attrs) do
    sc |> SuperCategoriaNativa.changeset(attrs) |> PsqlRepo.update()
  end

  def eliminar(%SuperCategoriaNativa{} = sc), do: PsqlRepo.delete(sc)
end
