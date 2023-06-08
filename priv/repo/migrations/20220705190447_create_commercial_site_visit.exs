defmodule BnApis.Repo.Migrations.CreateCommercialSiteVisit do
  use Ecto.Migration

  def change do
    create table(:commercial_site_visits) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :visit_status, :integer
      add :visit_date, :integer
      add :created_at, :integer
      add :visit_remarks, :string
      add :is_active, :boolean, default: true
      add :commercial_property_post_id, references(:commercial_property_posts)
      add :assigned_manager_id, references(:employees_credentials)
      add :broker_id, references(:brokers)
      timestamps()
    end
  end
end
