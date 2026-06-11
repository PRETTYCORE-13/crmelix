defmodule Prettycore.PsqlRepo.Migrations.AddValidationsToMetaColumns do
  use Ecto.Migration

  def change do
    alter table(:meta_columns) do
      add :requerido,    :boolean, default: false, null: false
      add :unico,        :boolean, default: false, null: false
      add :min_longitud, :integer
      add :max_longitud, :integer
    end
  end
end
