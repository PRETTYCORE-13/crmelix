defmodule Prettycore.Catalogos.Supercategorias.SupercategoriasContext do
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Supercategorias.Supercategoria

  def listar_supercategorias, do: Repo.all(Supercategoria)

  def obtener_supercategoria(id), do: Repo.get(Supercategoria, id)

  def buscar_supercategoria(id) do
    case obtener_supercategoria(id) do
      nil              -> {:error, :not_found}
      supercategoria   -> {:ok, supercategoria}
    end
  end

  def crear_supercategoria(attrs) do
    %Supercategoria{} |> Supercategoria.changeset(attrs) |> Repo.insert()
  end

  def actualizar_supercategoria(%Supercategoria{} = s, attrs) do
    s |> Supercategoria.changeset(attrs) |> Repo.update()
  end
end
