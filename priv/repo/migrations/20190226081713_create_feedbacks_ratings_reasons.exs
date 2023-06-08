defmodule BnApis.Repo.Migrations.CreateFeedbacksRatingsReasons do
  use Ecto.Migration

  def change do
    create table(:feedbacks_ratings_reasons, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false
      add :feedback_rating_id, references(:feedbacks_ratings, on_delete: :nothing)

      timestamps()
    end

    create index(:feedbacks_ratings_reasons, [:feedback_rating_id])
  end
end
