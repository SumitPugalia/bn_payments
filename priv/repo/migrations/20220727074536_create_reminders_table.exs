defmodule BnApis.Repo.Migrations.CreateRemindersTable do
  use Ecto.Migration

  def change do
    create table(:reminders) do
      add :status_id, :integer
      add :reminder_date, :integer
      add :entity_id, :integer
      add :remarks, :string
      add :entity_type, :string
      add :active, :boolean, default: true
      add :created_by_id, references(:employees_credentials)

      timestamps()
    end
  end
end
