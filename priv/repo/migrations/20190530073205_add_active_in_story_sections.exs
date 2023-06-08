defmodule BnApis.Repo.Migrations.AddActiveInStorySections do
  use Ecto.Migration

  def change do
    alter table(:stories_sections) do
      add :active, :boolean, default: true
    end
  end
end
