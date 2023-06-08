defmodule BnApis.Repo.Migrations.ModifyRemarkInHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      modify :remarks, :text
    end
  end
end
