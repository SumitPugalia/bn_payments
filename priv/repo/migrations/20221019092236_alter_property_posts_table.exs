defmodule BnApis.Repo.Migrations.AlterPropertyPostsTable do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :action_via_slash, :boolean, default: false, null: false
    end

    alter table(:resale_property_posts) do
      add :action_via_slash, :boolean, default: false, null: false
    end
  end
end
