defmodule BnApis.Repo.Migrations.CreateRentalMatches do
  use Ecto.Migration

  def change do
    create table(:rental_matches) do
      add :rent_ed, :decimal
      add :bachelor_ed, :integer
      add :furnishing_ed, :integer
      add :edit_distance, :decimal
      add :rental_client_id, references(:rental_client_posts, on_delete: :nothing)
      add :rental_property_id, references(:rental_property_posts, on_delete: :nothing)

      timestamps()
    end

    create index(:rental_matches, [:rental_client_id])
    create index(:rental_matches, [:rental_property_id])

    create unique_index(:rental_matches, [:rental_property_id, :rental_client_id],
             name: :rental_matches_ids_index
           )
  end
end
