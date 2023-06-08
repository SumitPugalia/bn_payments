defmodule BnApis.Repo.Migrations.CreateFeedTransactionProjects do
  use Ecto.Migration

  def change do
    create table(:feed_transaction_projects) do
      add(:feed_project_id, :integer)
      add(:feed_project_name, :string)

      add :story_id, references(:stories, on_delete: :nothing)

      timestamps()
    end

    create(unique_index(:feed_transaction_projects, [:story_id]))
    create(unique_index(:feed_transaction_projects, [:feed_project_id]))
  end
end
