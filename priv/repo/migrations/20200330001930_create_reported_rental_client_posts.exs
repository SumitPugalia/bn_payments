defmodule BnApis.Repo.Migrations.CreateReportedRentalClientPosts do
  use Ecto.Migration

  def change do
    create table(:reported_rental_client_posts) do
      add :rental_client_id, references(:rental_client_posts, on_delete: :nothing)
      add :reported_by_id, references(:credentials, on_delete: :nothing)
      add :report_post_reason_id, references(:reasons, on_delete: :nothing)

      timestamps()
    end

    create index(:reported_rental_client_posts, [:rental_client_id])
    create index(:reported_rental_client_posts, [:reported_by_id])
    create index(:reported_rental_client_posts, [:report_post_reason_id])

    create unique_index(:reported_rental_client_posts, [:reported_by_id, :rental_client_id],
             name: :a_re_reporting_not_allowed_index
           )
  end
end
