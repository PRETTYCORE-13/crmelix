defmodule Prettycore.SchemaRead do
  @moduledoc """
  Contexto para productos. Lee de PostgreSQL y sincroniza desde la API cuando se requiere.
  """
  require Logger

  import Ecto.Query
  alias Prettycore.PsqlRepo

#funcion que cuenta el numero de elementos de cualquier tabla
  def count_tx(tx) do
    PsqlRepo.aggregate(tx, :count)
  end

  #funcion que lista contenido de cualquier tabla paginado
  def lista_schema(tra, offset, limit) do
    PsqlRepo.all(from p in tra, order_by: p.inserted_at, offset: ^offset, limit: ^limit)
  end

  def obtener_por_id(schema, id) do
    PsqlRepo.get(schema, id)
  end

  def buscar_por_condiciones(schema, condiciones) when map_size(condiciones) == 0 do
    PsqlRepo.all(schema)
  end

  def buscar_por_condiciones(schema, condiciones) do
    filtros = Enum.reduce(condiciones, dynamic(true), fn {campo, valor}, acc ->
      campo_atom = String.to_existing_atom(campo)
      dynamic([p], ^acc and field(p, ^campo_atom) == ^valor)
    end)

    PsqlRepo.all(from p in schema, where: ^filtros)
  end

end
