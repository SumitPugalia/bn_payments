defmodule BnApis.Repo.Migrations.CreateRawPostLogs do
  use Ecto.Migration

  def change do
    create table(:raw_post_logs) do
      add :changes, :map, null: false
      add :user_id, :integer
      add :user_type, :string
      add :raw_entity_type, :string, null: false
      add :raw_entity_id, :integer, null: false
      timestamps()
    end
  end
end
