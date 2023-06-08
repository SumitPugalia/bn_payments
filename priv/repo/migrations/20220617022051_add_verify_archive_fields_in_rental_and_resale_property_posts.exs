defmodule BnApis.Repo.Migrations.AddVerifyArchiveFieldsInRentalAndResalePropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :last_archived_at, :naive_datetime
      add :last_verified_at, :naive_datetime
      add :verified_by_employees_credentials_id, references(:employees_credentials)
    end

    alter table(:rental_property_posts) do
      add :last_archived_at, :naive_datetime
      add :last_verified_at, :naive_datetime
      add :verified_by_employees_credentials_id, references(:employees_credentials)
    end
  end
end
