defmodule BnApis.Repo.Migrations.AddArchivedByEmployeesCredentialsIdInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :archived_by_employees_credentials_id,
          references(:employees_credentials, on_delete: :nothing)
    end
  end
end
