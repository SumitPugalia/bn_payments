defmodule BnApis.Repo.Migrations.AddAssignedOwnerIdInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :assigned_owner_id, references(:owners, on_delete: :nothing)
    end
  end
end
