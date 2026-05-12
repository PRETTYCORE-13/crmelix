defmodule Prettycore.PsqlRepo.Migrations.AddFormDataToUserAddresses do
  use Ecto.Migration

  def change do
    alter table(:user_addresses) do
      add :form_data, :map, null: true
    end
  end
end
