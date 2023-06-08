defmodule BnApis.Repo.Migrations.AddEditedAttrbsInRentalResalePosts do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :last_edited_at, :naive_datetime
      add :edited_by_employees_credentials_id, references(:employees_credentials)
    end

    alter table(:rental_property_posts) do
      add :last_edited_at, :naive_datetime
      add :edited_by_employees_credentials_id, references(:employees_credentials)
    end
  end
end
