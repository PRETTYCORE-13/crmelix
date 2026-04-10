defmodule Prettycore.PsqlRepo.Migrations.CreateProductosNativos do
  use Ecto.Migration

  def change do
    create table(:productos_nativos, primary_key: false) do
      add :codigo,      :string,  primary_key: true, null: false
      add :descripcion, :string,  null: false
      add :desc_corta,  :string
      add :precio_base, :float,   default: 0.0, null: false
      add :imagen_url,  :string
      add :activo,      :boolean, default: true, null: false
      add :stock,       :integer
      add :unidad,      :string,  default: "PZA"
      add :marca,       :string
      add :notas,       :text

      timestamps(type: :utc_datetime)
    end

    create index(:productos_nativos, [:activo])
  end
end
