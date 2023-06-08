defmodule BnApis.Repo.Migrations.AddOperatingCitiesForStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :operating_cities, {:array, :integer}, default: []
    end
  end
end
