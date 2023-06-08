defmodule BnApis.Repo.Migrations.AddDeleteReasonIdInRentalClientPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_client_posts) do
      add :archived_reason_id, references(:reasons, on_delete: :nothing)
    end
  end
end
