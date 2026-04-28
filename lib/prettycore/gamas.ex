defmodule Prettycore.Gamas do
  @moduledoc "Gestión de gamas de productos (catálogos visibles por cliente)."

  import Ecto.Query
  alias Prettycore.PsqlRepo
  alias Prettycore.Gamas.Gama

  # Código reservado para la fila de metadatos de cada gama (almacena el nombre).
  @meta "__meta__"

  @doc "Lista de gamas con número y nombre, ordenadas."
  def list_gamas do
    PsqlRepo.all(
      from g in Gama,
        select: %{numero: g.numero, nombre: g.nombre},
        distinct: [g.numero],
        order_by: g.numero
    )
  end

  @doc "Números de gama existentes, ordenados."
  def numeros_disponibles do
    PsqlRepo.all(from g in Gama, select: g.numero, distinct: true, order_by: g.numero)
  end

  @doc "Crea una gama vacía con nombre persistido (fila sentinel)."
  def crear_gama(numero, nombre) do
    %Gama{}
    |> Gama.changeset(%{numero: numero, nombre: nombre, producto_codigo: @meta})
    |> PsqlRepo.insert(on_conflict: {:replace, [:nombre]}, conflict_target: [:numero, :producto_codigo])
  end

  @doc "Nombre de una gama (del primer registro que tenga nombre)."
  def nombre_gama(numero) do
    PsqlRepo.one(
      from g in Gama,
        where: g.numero == ^numero and not is_nil(g.nombre),
        select: g.nombre,
        limit: 1
    )
  end

  @doc "Todos los códigos de producto en una gama (excluye fila de metadatos)."
  def codigos_en_gama(numero) do
    PsqlRepo.all(
      from g in Gama,
        where: g.numero == ^numero and g.producto_codigo != @meta,
        select: g.producto_codigo,
        order_by: g.producto_codigo
    )
  end

  @doc "MapSet de códigos en una gama (para lookup O(1))."
  def codigos_set(numero) do
    numero |> codigos_en_gama() |> MapSet.new()
  end

  @doc "Todos los códigos de producto en una lista de gamas (una sola query, sin duplicados)."
  def codigos_en_gamas([]), do: []
  def codigos_en_gamas(numeros) do
    PsqlRepo.all(
      from g in Gama,
        where: g.numero in ^numeros and g.producto_codigo != @meta,
        select: g.producto_codigo,
        distinct: true
    )
  end

  @doc "MapSet de códigos para múltiples gamas."
  def codigos_set_para_gamas(numeros) do
    numeros |> codigos_en_gamas() |> MapSet.new()
  end

  @doc "¿Está el producto en la gama?"
  def en_gama?(numero, producto_codigo) do
    PsqlRepo.exists?(from g in Gama, where: g.numero == ^numero and g.producto_codigo == ^producto_codigo)
  end

  @doc "Agrega un producto a la gama (copia el nombre de la fila meta si existe)."
  def agregar(numero, producto_codigo) do
    nombre = nombre_gama(numero)
    %Gama{}
    |> Gama.changeset(%{numero: numero, nombre: nombre, producto_codigo: producto_codigo})
    |> PsqlRepo.insert(on_conflict: :nothing)
  end

  @doc "Quita un producto de la gama (no toca la fila meta)."
  def quitar(numero, producto_codigo) do
    PsqlRepo.delete_all(
      from g in Gama,
        where: g.numero == ^numero and g.producto_codigo == ^producto_codigo
              and g.producto_codigo != @meta
    )
    :ok
  end

  @doc "Alterna la presencia de un producto en la gama."
  def toggle(numero, producto_codigo) do
    if en_gama?(numero, producto_codigo) do
      quitar(numero, producto_codigo)
    else
      agregar(numero, producto_codigo)
    end
  end

  @doc "Establece el nombre descriptivo de una gama (actualiza todos sus registros)."
  def set_nombre(numero, nombre) do
    PsqlRepo.update_all(
      from(g in Gama, where: g.numero == ^numero),
      set: [nombre: nombre]
    )
  end

  @doc "Elimina todos los productos de una gama."
  def eliminar_gama(numero) do
    PsqlRepo.delete_all(from g in Gama, where: g.numero == ^numero)
  end
end
