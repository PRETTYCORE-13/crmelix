defmodule Prettycore.Carrusel do
  import Ecto.Query
  alias Prettycore.PsqlRepo, as: Repo
  alias Prettycore.Carrusel.Imagen

  def list_all do
    Repo.all(from i in Imagen, order_by: [asc: i.orden, asc: i.inserted_at])
  end

  def list_activas do
    Repo.all(from i in Imagen, where: i.activo == true, order_by: [asc: i.orden, asc: i.inserted_at])
  end

  def create_imagen(attrs) do
    %Imagen{} |> Imagen.changeset(attrs) |> Repo.insert()
  end

  def update_imagen(%Imagen{} = img, attrs) do
    img |> Imagen.changeset(attrs) |> Repo.update()
  end

  def delete_imagen(%Imagen{} = img), do: Repo.delete(img)

  def toggle_activo(%Imagen{} = img) do
    update_imagen(img, %{activo: not img.activo})
  end

  def mover_arriba(%Imagen{} = img) do
    imagenes = list_all()
    idx = Enum.find_index(imagenes, &(&1.id == img.id))
    if idx && idx > 0 do
      prev = Enum.at(imagenes, idx - 1)
      Repo.transaction(fn ->
        update_imagen(img, %{orden: prev.orden})
        update_imagen(prev, %{orden: img.orden})
      end)
    end
    :ok
  end

  def mover_abajo(%Imagen{} = img) do
    imagenes = list_all()
    idx = Enum.find_index(imagenes, &(&1.id == img.id))
    if idx && idx < length(imagenes) - 1 do
      next = Enum.at(imagenes, idx + 1)
      Repo.transaction(fn ->
        update_imagen(img, %{orden: next.orden})
        update_imagen(next, %{orden: img.orden})
      end)
    end
    :ok
  end
end
