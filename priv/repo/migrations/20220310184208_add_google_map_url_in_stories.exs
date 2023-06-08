defmodule BnApis.Repo.Migrations.AddGoogleMapUrlInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:google_maps_url, :string)
    end
  end
end
