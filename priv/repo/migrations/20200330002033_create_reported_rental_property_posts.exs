defmodule BnApis.Repo.Migrations.CreateReportedRentalPropertyPosts do
  use Ecto.Migration

  def change do
    create table(:reported_rental_property_posts) do
      add :rental_property_id, references(:rental_property_posts, on_delete: :nothing)
      add :reported_by_id, references(:credentials, on_delete: :nothing)
      add :report_post_reason_id, references(:reasons, on_delete: :nothing)

      timestamps()
    end

    create index(:reported_rental_property_posts, [:rental_property_id])
    create index(:reported_rental_property_posts, [:reported_by_id])
    create index(:reported_rental_property_posts, [:report_post_reason_id])

    create unique_index(:reported_rental_property_posts, [:reported_by_id, :rental_property_id],
             name: :b_re_reporting_not_allowed_index
           )
  end
end
