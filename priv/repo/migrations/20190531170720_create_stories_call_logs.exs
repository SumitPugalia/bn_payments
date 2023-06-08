defmodule BnApis.Repo.Migrations.CreateStoriesCallLogs do
  use Ecto.Migration

  def change do
    create table(:stories_call_logs) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :phone_number, :string
      add :start_time, :naive_datetime
      add :end_time, :naive_datetime
      add :story_id, references(:stories, on_delete: :nothing)

      timestamps()
    end
  end
end
