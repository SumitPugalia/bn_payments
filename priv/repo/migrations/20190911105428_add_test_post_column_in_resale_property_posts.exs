defmodule BnApis.Repo.Migrations.AddTestPostColumnInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :test_post, :boolean, default: false
    end
  end
end
