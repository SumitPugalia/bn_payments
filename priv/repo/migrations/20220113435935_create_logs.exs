defmodule BnApis.Repo.Migrations.CreateLogs do
  use Ecto.Migration

  def change do
    create table(:logs) do
      add :changes, :jsonb
      add :entity_id, :integer, null: false
      add :entity_type, :string, null: false
      add :user_id, :integer
      add :user_type, :string
      timestamps()
    end

    create index(:logs, [:entity_id])
    create index(:logs, [:entity_type])
  end
end
