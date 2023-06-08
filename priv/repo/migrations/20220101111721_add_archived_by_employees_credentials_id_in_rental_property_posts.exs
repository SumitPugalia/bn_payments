defmodule BnApis.Repo.Migrations.AddArchivedByEmployeesCredentialsIdInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :archived_by_employees_credentials_id,
          references(:employees_credentials, on_delete: :nothing)
    end
  end
end
