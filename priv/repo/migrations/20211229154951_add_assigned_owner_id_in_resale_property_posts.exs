defmodule BnApis.Repo.Migrations.AddAssignedOwnerIdInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :assigned_owner_id, references(:owners, on_delete: :nothing)
    end
  end
end
