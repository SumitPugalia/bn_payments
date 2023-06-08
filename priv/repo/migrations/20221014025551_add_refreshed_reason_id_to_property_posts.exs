defmodule BnApis.Repo.Migrations.AddRefreshedReasonIdToPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :refreshed_reason_id, references(:reasons, on_delete: :nothing)
    end

    alter table(:rental_property_posts) do
      add :refreshed_reason_id, references(:reasons, on_delete: :nothing)
    end
  end
end
