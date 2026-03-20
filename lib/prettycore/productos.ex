defmodule Prettycore.Productos do
  @moduledoc """
  Contexto para productos. Lee de PostgreSQL y sincroniza desde la API cuando se requiere.
  """
  require Logger

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.Productos.Producto
  alias Prettycore.Api.Client

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

  @doc "Sincroniza productos desde la API y los guarda en PostgreSQL. Retorna {:ok, count} o {:error, reason}."
  def sync_from_api do
    case Client.get_productos() do
      {:ok, registros} when is_list(registros) ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)

        entries =
          registros
          |> Enum.filter(fn r -> r["PRODUC_CODIGO_K"] not in [nil, ""] end)
          |> Enum.map(fn r ->
            %{
              codigo: to_string(r["PRODUC_CODIGO_K"]),
              descripcion: r["PRODUC_DESCRIPCION"],
              desc_corta: r["PRODUC_DESCCORTA"],
              marca: r["PROMAR_CODIGO_K"],
              iva: r["PRODUC_IVA"] || 0.0,
              pzas_min_vta: r["PRODUC_PZAMINVTA"] || 1,
              activo: r["PRODUC_ACTIVO"] == 1,
              raw: r,
              inserted_at: now,
              updated_at: now
            }
          end)

        {count, _} =
          PsqlRepo.insert_all(
            Producto,
            entries,
            on_conflict: {:replace, [:descripcion, :desc_corta, :marca, :iva, :pzas_min_vta, :activo, :raw, :updated_at]},
            conflict_target: :codigo
          )

        Logger.info("Productos sincronizados: #{count} registros")
        {:ok, count}

      {:error, reason} ->
        Logger.error("Error sincronizando productos: #{inspect(reason)}")
        {:error, reason}
    end
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
