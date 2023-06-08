defmodule BnApis.Repo.Migrations.CreateReportedResaleClientPosts do
  use Ecto.Migration

  def change do
    create table(:reported_resale_client_posts) do
      add :resale_client_id, references(:resale_client_posts, on_delete: :nothing)
      add :reported_by_id, references(:credentials, on_delete: :nothing)
      add :report_post_reason_id, references(:reasons, on_delete: :nothing)

      timestamps()
    end

    create index(:reported_resale_client_posts, [:resale_client_id])
    create index(:reported_resale_client_posts, [:reported_by_id])
    create index(:reported_resale_client_posts, [:report_post_reason_id])

    create unique_index(:reported_resale_client_posts, [:reported_by_id, :resale_client_id],
             name: :c_re_reporting_not_allowed_index
           )
  end
end
