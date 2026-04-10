defmodule Prettycore.ProductosNativos do
  @moduledoc "Gestión de productos nativos creados directamente en PostgreSQL (no provienen de la API)."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.ProductosNativos.ProductoNativo

  @doc "Lista todos los productos nativos activos (para mostrar en tienda)."
  def list_activos do
    PsqlRepo.all(from p in ProductoNativo, where: p.activo == true, order_by: p.descripcion)
  end

  @doc "Lista todos (admin)."
  def list_todos do
    PsqlRepo.all(from p in ProductoNativo, order_by: [desc: p.inserted_at])
  end

  @doc "Busca por descripción o código."
  def search(q) do
    term = "%#{String.downcase(q)}%"
    PsqlRepo.all(
      from p in ProductoNativo,
        where: ilike(p.descripcion, ^term) or ilike(p.codigo, ^term),
        order_by: p.descripcion
    )
  end

  @doc "Obtiene un producto por código."
  def get(codigo), do: PsqlRepo.get(ProductoNativo, codigo)

  @doc "Genera el siguiente código disponible en formato PROD-NNN."
  def next_codigo do
    existing =
      PsqlRepo.all(
        from p in ProductoNativo,
          where: like(p.codigo, "PROD-%"),
          select: p.codigo
      )

    used =
      existing
      |> Enum.flat_map(fn c ->
        case Integer.parse(String.replace_prefix(c, "PROD-", "")) do
          {n, ""} -> [n]
          _       -> []
        end
      end)
      |> MapSet.new()

    next = Stream.iterate(1, &(&1 + 1)) |> Enum.find(&(not MapSet.member?(used, &1)))
    "PROD-#{String.pad_leading(to_string(next), 3, "0")}"
  end

  @doc "Asigna una categoría a los productos en la lista y la quita a los que ya no están."
  def asignar_categoria(cat_nombre, codigos_asignados) do
    codigos_set = MapSet.new(codigos_asignados)
    PsqlRepo.all(from p in ProductoNativo)
    |> Enum.each(fn p ->
      cond do
        MapSet.member?(codigos_set, p.codigo) and p.categoria != cat_nombre ->
          p |> ProductoNativo.changeset(%{"categoria" => cat_nombre}) |> PsqlRepo.update()
        not MapSet.member?(codigos_set, p.codigo) and p.categoria == cat_nombre ->
          p |> ProductoNativo.changeset(%{"categoria" => nil}) |> PsqlRepo.update()
        true -> :ok
      end
    end)
  end

  @doc "Crea un producto nativo."
  def crear(attrs) do
    %ProductoNativo{}
    |> ProductoNativo.changeset(attrs)
    |> PsqlRepo.insert()
  end

  @doc "Actualiza un producto nativo."
  def actualizar(%ProductoNativo{} = p, attrs) do
    p
    |> ProductoNativo.changeset(attrs)
    |> PsqlRepo.update()
  end

  @doc "Actualiza la imagen de un producto nativo por código."
  def update_imagen(codigo, url) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {count, _} =
      PsqlRepo.update_all(
        from(p in ProductoNativo, where: p.codigo == ^codigo),
        set: [imagen_url: url, updated_at: now]
      )
    if count > 0, do: {:ok, count}, else: {:error, :not_found}
  end

  @doc "Elimina un producto nativo."
  def eliminar(%ProductoNativo{} = p), do: PsqlRepo.delete(p)

  @doc "Devuelve %{codigo => precio_base} para los activos con precio > 0."
  def get_precios_map do
    PsqlRepo.all(
      from p in ProductoNativo,
        where: p.activo == true and p.precio_base > 0.0,
        select: {p.codigo, p.precio_base}
    )
    |> Map.new()
  end

  @doc "Devuelve %{codigo => ProductoNativo} para los activos (usado en carrito)."
  def get_nativos_map do
    list_activos() |> Map.new(&{&1.codigo, &1})
  end

  @doc "Convierte un ProductoNativo a un mapa compatible con la template de tienda."
  def to_tienda_map(%ProductoNativo{} = p) do
    %{
      codigo:       p.codigo,
      descripcion:  p.descripcion,
      desc_corta:   p.desc_corta || "",
      imagen_url:   p.imagen_url || "",
      activo:       p.activo,
      updated_at:   p.updated_at,
      pzas_min_vta: 1,
      marca:        p.marca || "",
      iva:          0.0,
      raw:          %{},
      nativo:       true,
      categoria:    p.categoria
    }
  end
end
