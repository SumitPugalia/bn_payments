defmodule BnApis.Repo.Migrations.AddRefreshedInReportedProperty do
  use Ecto.Migration

  def change do
    alter table(:reported_resale_property_posts) do
      add :refreshed_on, :naive_datetime
      add :refresh_note, :text
      add :refreshed_by_id, references(:employees_credentials, on_delete: :nothing)
    end

    alter table(:reported_rental_property_posts) do
      add :refreshed_on, :naive_datetime
      add :refresh_note, :text
      add :refreshed_by_id, references(:employees_credentials, on_delete: :nothing)
    end
  end
end
