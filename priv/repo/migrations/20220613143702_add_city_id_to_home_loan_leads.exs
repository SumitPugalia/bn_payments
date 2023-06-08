defmodule BnApis.Repo.Migrations.AddCityIdToHomeLoanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add :city_id, :integer
    end
  end
end
