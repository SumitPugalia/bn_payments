defmodule BnApis.Repo.Migrations.CreateFeedbacks do
  use Ecto.Migration

  def change do
    create table(:feedbacks) do
      add :feedback_session_id, references(:feedbacks_sessions, on_delete: :nothing)
      add :feedback_rating_id, references(:feedbacks_ratings, on_delete: :nothing)
      add :feedback_rating_reason_id, references(:feedbacks_ratings_reasons, on_delete: :nothing)
      add :feedback_by_id, references(:credentials, on_delete: :nothing)
      add :feedback_for_id, references(:credentials, on_delete: :nothing)

      timestamps()
    end

    create index(:feedbacks, [:feedback_session_id])
    create index(:feedbacks, [:feedback_rating_id])
    create index(:feedbacks, [:feedback_rating_reason_id])
    create index(:feedbacks, [:feedback_by_id])
    create index(:feedbacks, [:feedback_for_id])

    create unique_index(:feedbacks, [:feedback_session_id, :feedback_by_id, :feedback_for_id],
             name: :feedback_uniqueness_index
           )

    create constraint(:feedbacks, "feedback_by_and_for_should_not_be_identical",
             check: "feedback_for_id <> feedback_by_id"
           )
  end
end
