defmodule Prettycore.Sucursales do
  @moduledoc "Gestión de sucursales."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.Sucursales.Sucursal

  def list_todas do
    PsqlRepo.all(from s in Sucursal, order_by: s.numero)
  end

  def list_activas do
    PsqlRepo.all(from s in Sucursal, where: s.activo == true, order_by: s.numero)
  end

  def get(id), do: PsqlRepo.get(Sucursal, id)

  def next_numero do
    used = PsqlRepo.all(from s in Sucursal, select: s.numero) |> MapSet.new()
    Stream.iterate(1, &(&1 + 1)) |> Enum.find(&(not MapSet.member?(used, &1)))
  end

  def crear(attrs) do
    %Sucursal{}
    |> Sucursal.changeset(attrs)
    |> PsqlRepo.insert()
  end

  def actualizar(%Sucursal{} = s, attrs) do
    s |> Sucursal.changeset(attrs) |> PsqlRepo.update()
  end

  def eliminar(%Sucursal{} = s), do: PsqlRepo.delete(s)
end
