defmodule Prettycore.PsqlRepo.Migrations.RenameModeloDestinoToContextoDestino do
  use Ecto.Migration

  def change do
    rename table(:meta_relations), :modelo_destino_id, to: :contexto_destino_id
  end
end
