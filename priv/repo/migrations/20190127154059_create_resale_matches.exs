defmodule BnApis.Repo.Migrations.CreateResaleMatches do
  use Ecto.Migration

  def change do
    create table(:resale_matches) do
      add :price_ed, :decimal
      add :area_ed, :decimal
      add :parking_ed, :integer
      add :floor_ed, :integer
      add :edit_distance, :decimal
      add :resale_client_id, references(:resale_client_posts, on_delete: :nothing)
      add :resale_property_id, references(:resale_property_posts, on_delete: :nothing)

      timestamps()
    end

    create index(:resale_matches, [:resale_client_id])
    create index(:resale_matches, [:resale_property_id])

    create unique_index(:resale_matches, [:resale_property_id, :resale_client_id],
             name: :resale_matches_ids_index
           )
  end
end
