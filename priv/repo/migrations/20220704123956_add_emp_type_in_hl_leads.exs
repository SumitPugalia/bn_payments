defmodule BnApis.Repo.Migrations.AddEmpTypeInHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add :employment_type, :integer
    end
  end
end
