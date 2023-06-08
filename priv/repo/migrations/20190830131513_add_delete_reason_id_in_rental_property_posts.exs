defmodule BnApis.Repo.Migrations.AddDeleteReasonIdInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :archived_reason_id, references(:reasons, on_delete: :nothing)
    end
  end
end
