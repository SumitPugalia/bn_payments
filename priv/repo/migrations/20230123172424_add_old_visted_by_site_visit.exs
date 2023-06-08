defmodule BnApis.Repo.Migrations.AddOldVistedBySiteVisit do
  use Ecto.Migration

  def change do
    alter table(:site_visits) do
      add :old_visited_by_id, references(:credentials)
      add :old_organization_id, references(:organizations)
    end
  end
end
