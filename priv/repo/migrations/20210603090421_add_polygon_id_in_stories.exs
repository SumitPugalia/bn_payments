defmodule BnApis.Repo.Migrations.AddPolygonIdInStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add(:polygon_id, references(:polygons))
    end
  end
end
