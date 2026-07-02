defmodule Prettycore.PsqlRepo.Migrations.CreateVentas do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:ventas) do
      add :sysudn_codigo_k,    :string
      add :liquid_fechaent,    :date
      add :cfgepl_nombre,      :string
      add :facdoc_referencia,  :string
      add :vtarut_codigo_k,    :string
      add :cred,               :string
      add :ctecli_codigo_k,    :string
      add :ctecli_dencomercia, :string
      add :ctecad_codigo_k,    :string
      add :ctetpo_codigo_k,    :string
      add :ctecan_codigo_k,    :string
      add :preventa,           :boolean, default: false
      add :ctepfr_codigo_k,    :string
      add :produc_codigo_k,    :string
      add :produc_descripcion, :string
      add :promar_codigo_k,    :string
      add :propre_codigo_k,    :string
      add :proseg_codigo_k,    :string
      add :prolna_codigo_k,    :string
      add :pzaliq,             :decimal, precision: 18, scale: 4
      add :vtaliq,             :decimal, precision: 18, scale: 4
      add :vtaliq_sn_iva,      :decimal, precision: 18, scale: 4
      add :invpro_costoprom,   :decimal, precision: 18, scale: 4
      add :rechazocajas,       :decimal, precision: 18, scale: 4
      add :rechazo,            :boolean, default: false

      timestamps()
    end

    create index(:ventas, [:liquid_fechaent])
    create index(:ventas, [:ctecli_codigo_k])
    create index(:ventas, [:produc_codigo_k])
  end
end
