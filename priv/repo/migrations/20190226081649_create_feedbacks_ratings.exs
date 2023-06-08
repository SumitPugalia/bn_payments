defmodule BnApis.Repo.Migrations.CreateFeedbacksRatings do
  use Ecto.Migration

  def change do
    create table(:feedbacks_ratings, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:feedbacks_ratings, [:name])
  end
end
