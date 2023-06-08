defmodule BnApis.Repo.Migrations.CreateMatchReadStatuses do
  use Ecto.Migration

  def change do
    create table(:match_read_statuses) do
      add :read, :boolean, default: false, null: false
      add :user_id, references(:credentials, on_delete: :nothing)
      add :rental_matches_id, references(:rental_matches, on_delete: :nothing)
      add :resale_matches_id, references(:resale_matches, on_delete: :nothing)

      timestamps()
    end

    create index(:match_read_statuses, [:user_id])
    create index(:match_read_statuses, [:rental_matches_id])
    create index(:match_read_statuses, [:resale_matches_id])
  end
end
