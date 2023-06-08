defmodule BnApis.Repo.Migrations.AddCreatedAtInLogs do
  use Ecto.Migration

  def change do
    alter table(:logs) do
      add :created_at, :naive_datetime
    end
  end
end
