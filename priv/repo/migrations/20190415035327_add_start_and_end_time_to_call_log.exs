defmodule BnApis.Repo.Migrations.AddStartAndEndTimeToCallLog do
  use Ecto.Migration

  def change do
    alter table(:call_logs) do
      remove :time_of_call
      add :start_time, :naive_datetime
      add :end_time, :naive_datetime
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :call_log_id, references(:call_logs, on_delete: :nothing)
    end

    alter table(:feedbacks_sessions) do
      add :start_time, :naive_datetime
    end

    create unique_index(:feedbacks_sessions, [:initiated_by_id, :start_time],
             name: :session_init_start_time
           )
  end
end
