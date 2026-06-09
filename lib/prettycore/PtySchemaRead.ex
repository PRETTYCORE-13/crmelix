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

end
