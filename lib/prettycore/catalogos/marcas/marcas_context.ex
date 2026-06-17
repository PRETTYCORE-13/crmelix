defmodule Prettycore.Catalogos.Marcas.MarcasContext do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Marcas.Marca

  def listar_marcas, do: Repo.all(Marca)

  def listar_marcas(offset, limit) do
    Marca |> offset(^offset) |> limit(^limit) |> Repo.all()
  end

  def count_marcas, do: Repo.aggregate(Marca, :count)

  def obtener_marca(id), do: Repo.get(Marca, id)

  def buscar_marca(id) do
    case obtener_marca(id) do
      nil   -> {:error, :not_found}
      marca -> {:ok, marca}
    end
  end

  def crear_marca(attrs) do
    %Marca{} |> Marca.changeset(attrs) |> Repo.insert()
  end

  def actualizar_marca(%Marca{} = marca, attrs) do
    marca |> Marca.changeset(attrs) |> Repo.update()
  end
end
