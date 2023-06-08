defmodule BnApis.Repo.Migrations.AddTestPostColumnInRentalClientPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_client_posts) do
      add :test_post, :boolean, default: false
    end
  end
end
