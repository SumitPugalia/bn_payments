defmodule BnApis.Repo.Migrations.AddReasonIdSiteVisit do
  use Ecto.Migration

  def change do
    alter table(:commercial_site_visits) do
      add :cancelled_by_id, references(:employees_credentials)
      add :completed_by_id, references(:employees_credentials)
      add :reason_id, references(:reasons)
    end
  end
end
