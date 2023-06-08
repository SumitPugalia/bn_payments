defmodule BnApis.Repo.Migrations.CreateBlockedUsers do
  use Ecto.Migration

  def change do
    create table(:blocked_users) do
      add :blocker, references(:credentials, on_delete: :nothing)
      add :blockee, references(:credentials, on_delete: :nothing)
      add :expires_on, :naive_datetime
      add :blocked, :boolean

      timestamps
    end
  end
end
