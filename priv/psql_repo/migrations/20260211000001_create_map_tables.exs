defmodule Prettycore.PsqlRepo.Migrations.CreateMapTables do
  use Ecto.Migration

  def change do
    # Estados (entidades federativas)
    create table(:map_estados, primary_key: false) do
      add :codigo_k, :integer, primary_key: true, null: false
      add :descripcion, :string, null: false
    end

    # Municipios — PK compuesta (estado, municipio)
    create table(:map_municipios, primary_key: false) do
      add :estado_codigo_k, references(:map_estados, column: :codigo_k, type: :integer),
        null: false, primary_key: true
      add :codigo_k, :integer, null: false, primary_key: true
      add :descripcion, :string, null: false
    end

    create index(:map_municipios, [:estado_codigo_k])

    # Localidades — PK compuesta (estado, municipio, localidad)
    create table(:map_localidades, primary_key: false) do
      add :estado_codigo_k, :integer, null: false, primary_key: true
      add :municipio_codigo_k, :integer, null: false, primary_key: true
      add :codigo_k, :integer, null: false, primary_key: true
      add :descripcion, :string, null: false
      add :cp, :string
    end

    create index(:map_localidades, [:estado_codigo_k, :municipio_codigo_k])
    create index(:map_localidades, [:cp])

    # FK compuesta localidades -> municipios (requiere SQL raw)
    execute(
      """
      ALTER TABLE map_localidades
        ADD CONSTRAINT map_localidades_municipio_fk
        FOREIGN KEY (estado_codigo_k, municipio_codigo_k)
        REFERENCES map_municipios (estado_codigo_k, codigo_k)
      """,
      "ALTER TABLE map_localidades DROP CONSTRAINT map_localidades_municipio_fk"
    )
  end
end
