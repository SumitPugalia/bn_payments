defmodule BnApis.Repo.Migrations.AddJoiningDateToCredentials do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :joining_date, :naive_datetime
    end
  end
end
