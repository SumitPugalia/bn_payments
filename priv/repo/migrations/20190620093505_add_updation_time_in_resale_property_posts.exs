defmodule BnApis.Repo.Migrations.AddUpdationTimeInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :updation_time, :naive_datetime
    end
  end
end
