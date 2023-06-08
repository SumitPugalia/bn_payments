defmodule BnApis.Repo.Migrations.AddOnboardedDateToStories do
  use Ecto.Migration

  def change do
    alter table(:stories) do
      add :onboarded_date, :naive_datetime
    end
  end
end
