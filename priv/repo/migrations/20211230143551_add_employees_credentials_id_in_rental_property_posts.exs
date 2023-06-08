defmodule BnApis.Repo.Migrations.AddEmployeesCredentialsIdInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :employees_credentials_id, references(:employees_credentials, on_delete: :nothing)
    end
  end
end
