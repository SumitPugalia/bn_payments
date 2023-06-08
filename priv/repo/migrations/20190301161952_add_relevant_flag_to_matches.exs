defmodule BnApis.Repo.Migrations.AddRelevantFlagToMatches do
  use Ecto.Migration

  def change do
    alter table(:rental_matches) do
      add :is_relevant, :boolean, default: true, null: false
      add :marked_by_id, references(:credentials, on_delete: :nothing)
    end

    alter table(:resale_matches) do
      add :is_relevant, :boolean, default: true, null: false
      add :marked_by_id, references(:credentials, on_delete: :nothing)
    end

    create index(:rental_matches, [:marked_by_id])
    create index(:resale_matches, [:marked_by_id])
  end
end
