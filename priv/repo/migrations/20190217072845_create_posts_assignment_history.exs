defmodule BnApis.Repo.Migrations.CreatePostsAssignmentHistory do
  use Ecto.Migration

  def change do
    create table(:posts_assignment_history) do
      add :start_date, :naive_datetime
      add :end_date, :naive_datetime
      add :rent_client_post_id, references(:rental_client_posts, on_delete: :nothing)
      add :rent_property_post_id, references(:rental_property_posts, on_delete: :nothing)
      add :resale_client_post_id, references(:resale_client_posts, on_delete: :nothing)
      add :resale_property_post_id, references(:resale_property_posts, on_delete: :nothing)
      add :user_id, references(:credentials, on_delete: :nothing)
      add :changed_by_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:posts_assignment_history, [:rent_client_post_id])
    create index(:posts_assignment_history, [:rent_property_post_id])
    create index(:posts_assignment_history, [:resale_client_post_id])
    create index(:posts_assignment_history, [:resale_property_post_id])
    create index(:posts_assignment_history, [:user_id])
    create index(:posts_assignment_history, [:changed_by_id])
  end
end
