defmodule BnApis.Repo.Migrations.AddRefreshedByEmployeesCredentialsIdInRentalPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:rental_property_posts) do
      add :refreshed_by_employees_credentials_id,
          references(:employees_credentials, on_delete: :nothing)

      add :is_offline, :boolean, default: true
    end
  end
end
