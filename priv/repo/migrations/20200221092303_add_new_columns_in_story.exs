defmodule BnApis.Repo.Migrations.AddNewColumnsInStory do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :min_carpet_area, :integer
      add :max_carpet_area, :integer
      add :possession_by, :naive_datetime
      add :thumbnail_image_url, :string
      add :project_logo_url, :string
      add :configuration_type_ids, {:array, :integer}
    end
  end
end
