defmodule Prettycore.PsqlRepo.Migrations.AddUniqueOrdenToCategorias do
  use Ecto.Migration

  def up do
    # Reasigna ordenes duplicados antes de agregar el índice único
    execute """
    UPDATE categorias SET orden = sub.new_orden
    FROM (
      SELECT id, ROW_NUMBER() OVER (ORDER BY orden, inserted_at) - 1 AS new_orden
      FROM categorias
    ) sub
    WHERE categorias.id = sub.id
    """

    # Eliminar índice existente (puede ser no-único) antes de recrear como único
    execute "DROP INDEX IF EXISTS categorias_orden_index"
    create unique_index(:categorias, [:orden])
  end

  def down do
    drop unique_index(:categorias, [:orden])
  end
end
