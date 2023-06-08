defmodule BnApis.Repo.Migrations.CreateReportedCommercialPropertyPost do
  use Ecto.Migration

  def change do
    create table(:reported_commercial_property_posts) do
      add :report_property_post_reason_id, references(:reasons)
      add :reported_by_id, references(:brokers)
      add :commercial_property_post_id, references(:commercial_property_posts), null: false
      add :remarks, :string
      timestamps()
    end

    create unique_index(
             :reported_commercial_property_posts,
             [:reported_by_id, :commercial_property_post_id],
             name: :commercial_post_re_reporting_not_allowed_index
           )
  end
end
