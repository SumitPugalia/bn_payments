defmodule BnApis.Repo.Migrations.AddLeadSquaredRefInHomeloanLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add :lead_squared_uuid, :string
    end
  end
end
