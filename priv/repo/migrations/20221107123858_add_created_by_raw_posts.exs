defmodule BnApis.Repo.Migrations.AddCreatedByRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add(:created_by_employee_credential_id, references(:employees_credentials))
    end

    alter table(:raw_resale_property_posts) do
      add(:created_by_employee_credential_id, references(:employees_credentials))
    end
  end
end
