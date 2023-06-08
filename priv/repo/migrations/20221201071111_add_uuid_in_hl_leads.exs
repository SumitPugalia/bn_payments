defmodule BnApis.Repo.Migrations.AddUuidInHlLeads do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
    end
  end
end
