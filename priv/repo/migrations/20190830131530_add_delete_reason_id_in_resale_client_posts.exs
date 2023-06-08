defmodule BnApis.Repo.Migrations.AddDeleteReasonIdInResaleClientPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_client_posts) do
      add :archived_reason_id, references(:reasons, on_delete: :nothing)
    end
  end
end
