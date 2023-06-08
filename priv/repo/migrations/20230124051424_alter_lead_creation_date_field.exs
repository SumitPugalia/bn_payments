defmodule BnApis.Repo.Migrations.AlterLeadCreationDateField do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      modify :lead_creation_date, :bigint
    end
  end
end
