defmodule BnApis.Repo.Migrations.AddTestPostColumnInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :test_post, :boolean, default: false
    end
  end
end
