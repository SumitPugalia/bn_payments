defmodule BnApis.Repo.Migrations.CreateBrokerSiteVisitsTable do
  use Ecto.Migration

  def change do
    create table(:site_visits) do
      add :reported_by_id, references(:developers_credentials, on_delete: :nothing)
      add :visited_by_id, references(:credentials, on_delete: :nothing)
      add :project_id, references(:projects, on_delete: :nothing)
      add :time_of_visit, :naive_datetime
      add :lead_reference, :string
      timestamps()
    end

    create index(:site_visits, [:visited_by_id])
  end
end
