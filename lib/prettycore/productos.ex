defmodule Prettycore.Productos do
  @moduledoc """
  Contexto para productos. Lee de PostgreSQL y sincroniza desde la API cuando se requiere.
  """
  require Logger

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.Productos.Producto

  @doc "Lista todos los productos desde la BD local."
  def list_productos do
    PsqlRepo.all(from p in Producto, order_by: p.descripcion)
  end

  @doc "Busca productos por descripción, código o marca."
  def search_productos(""), do: list_productos()
  def search_productos(q) do
    term = "%#{String.downcase(q)}%"
    PsqlRepo.all(
      from p in Producto,
        where:
          ilike(p.descripcion, ^term) or
          ilike(p.codigo, ^term) or
          ilike(p.marca, ^term),
        order_by: p.descripcion
    )
  end

  @doc "Actualiza la imagen de un producto por su código. Retorna {:ok, count} o {:error, :not_found}."
  def update_imagen(codigo, url) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {count, _} =
      PsqlRepo.update_all(
        from(p in Producto, where: p.codigo == ^codigo),
        set: [imagen_url: url, updated_at: now]
      )
    if count > 0, do: {:ok, count}, else: {:error, :not_found}
  end

  @doc "Busca productos exactamente o parcialmente por SKU (codigo)."
  def search_by_sku(""), do: []
  def search_by_sku(q) do
    term = "%#{q}%"
    PsqlRepo.all(from p in Producto, where: ilike(p.codigo, ^term), order_by: p.codigo)
  end

  @doc "Busca productos por descripción o descripción corta."
  def search_by_descrip(""), do: []
  def search_by_descrip(q) do
    term = "%#{q}%"
    PsqlRepo.all(
      from p in Producto,
        where: ilike(p.descripcion, ^term) or ilike(p.desc_corta, ^term),
        order_by: p.descripcion
    )
  end

  @doc "Inserta o actualiza un producto. Retorna {:ok, producto} o {:error, changeset}."
  def upsert_producto(attrs) do
    codigo = Map.get(attrs, "codigo") || Map.get(attrs, :codigo)
    (PsqlRepo.get(Producto, codigo) || %Producto{})
    |> Producto.changeset(attrs)
    |> PsqlRepo.insert_or_update()
  end

  @doc "Retorna true si la tabla de productos está vacía."
  def empty? do
    PsqlRepo.aggregate(Producto, :count) == 0
  end

  @doc "Lista productos filtrados por nombre de categoría. 'Todos' retorna todos."
  def list_by_categoria(cat) when cat in ["Todos", "INICIO", nil], do: list_productos()
  def list_by_categoria(nombre) do
    PsqlRepo.all(
      from p in Producto,
        join: cp in "categoria_productos", on: cp.producto_codigo == p.codigo,
        join: c in Prettycore.Categorias.Categoria, on: c.id == cp.categoria_id,
        where: c.nombre == ^nombre,
        order_by: p.descripcion
    )
  end

  @doc "Busca productos dentro de una categoría. 'Todos' busca en todo."
  def search_by_categoria("", cat), do: list_by_categoria(cat)
  def search_by_categoria(q, cat) when cat in ["Todos", "INICIO", nil], do: search_productos(q)
  def search_by_categoria(q, nombre) do
    term = "%#{String.downcase(q)}%"
    PsqlRepo.all(
      from p in Producto,
        join: cp in "categoria_productos", on: cp.producto_codigo == p.codigo,
        join: c in Prettycore.Categorias.Categoria, on: c.id == cp.categoria_id,
        where: c.nombre == ^nombre and
               (ilike(p.descripcion, ^term) or ilike(p.codigo, ^term) or ilike(p.marca, ^term)),
        order_by: p.descripcion
    )
  end
end
