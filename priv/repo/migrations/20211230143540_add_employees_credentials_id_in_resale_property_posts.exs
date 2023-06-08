defmodule BnApis.Repo.Migrations.AddEmployeesCredentialsIdInResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :employees_credentials_id, references(:employees_credentials, on_delete: :nothing)
    end
  end
end
