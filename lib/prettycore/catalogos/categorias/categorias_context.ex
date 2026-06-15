defmodule Prettycore.Catalogos.Categorias.CategoriasContext do
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Catalogos.Categorias.Categoria

  def listar_categorias, do: Repo.all(Categoria)

  def obtener_categoria(id), do: Repo.get(Categoria, id)

  def buscar_categoria(id) do
    case obtener_categoria(id) do
      nil       -> {:error, :not_found}
      categoria -> {:ok, categoria}
    end
  end

  def crear_categoria(attrs) do
    %Categoria{} |> Categoria.changeset(attrs) |> Repo.insert()
  end

  def actualizar_categoria(%Categoria{} = c, attrs) do
    c |> Categoria.changeset(attrs) |> Repo.update()
  end
end
