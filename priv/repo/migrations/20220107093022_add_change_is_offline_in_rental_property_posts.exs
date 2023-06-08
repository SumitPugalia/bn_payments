defmodule BnApis.Repo.Migrations.AddChangeIsOfflineInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      modify :is_offline, :boolean, default: false
    end

    alter table(:rental_property_posts) do
      modify :is_offline, :boolean, default: false
    end
  end
end
