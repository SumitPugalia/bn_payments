defmodule BnApis.Repo.Migrations.AddFieldToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :phone_number, :string
      add :contact_person_name, :string
    end
  end
end
