defmodule BnApis.Repo.Migrations.AddTestPostColumnInResaleClientPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_client_posts) do
      add :test_post, :boolean, default: false
    end
  end
end
