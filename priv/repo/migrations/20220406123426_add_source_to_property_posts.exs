defmodule BnApis.Repo.Migrations.AddSourceToPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :source, :string
    end

    alter table(:resale_property_posts) do
      add :source, :string
    end
  end
end
