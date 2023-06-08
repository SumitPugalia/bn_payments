defmodule BnApis.Repo.Migrations.AddUniquenessToMatchesRead do
  use Ecto.Migration

  def change do
    create unique_index(:match_read_statuses, [:user_id, :rental_matches_id],
             name: :user_rental_match_uniqueness
           )

    create unique_index(:match_read_statuses, [:user_id, :resale_matches_id],
             name: :user_resale_match_uniqueness
           )
  end
end
