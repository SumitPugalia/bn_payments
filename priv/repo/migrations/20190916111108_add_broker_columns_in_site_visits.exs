defmodule BnApis.Repo.Migrations.AddBrokerColumnsInSiteVisits do
  use Ecto.Migration

  def change do
    alter table(:site_visits) do
      add :broker_phone_number, :string
      add :broker_name, :string
      add :broker_email, :string
      add :lead_reference_name, :string
      add :lead_reference_email, :string
    end
  end
end
