defmodule BnApis.Repo.Migrations.AddJidRemindersTable do
  use Ecto.Migration

  def change do
    alter table(:reminders) do
      remove :active
      add :jid, :string
    end
  end
end
