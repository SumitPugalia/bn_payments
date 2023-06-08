defmodule BnApis.Repo.Migrations.AddCallLogToMatches do
  use Ecto.Migration

  def change do
    # Reference outgoing call_log to matches
    alter table(:rental_matches) do
      remove :marked_by_id
      add :feedback_by_id, references(:credentials, on_delete: :nothing)
      add :outgoing_call_log_id, references(:call_logs, on_delete: :nothing)
    end

    drop_if_exists index(:rental_matches, [:marked_by_id])
    create index(:rental_matches, [:feedback_by_id])
    create index(:rental_matches, [:outgoing_call_log_id])

    alter table(:resale_matches) do
      remove :marked_by_id
      add :feedback_by_id, references(:credentials, on_delete: :nothing)
      add :outgoing_call_log_id, references(:call_logs, on_delete: :nothing)
    end

    drop_if_exists index(:resale_matches, [:marked_by_id])
    create index(:resale_matches, [:feedback_by_id])
    create index(:resale_matches, [:outgoing_call_log_id])

    # Reference Feedback session to call_log
    alter table(:call_logs) do
      add :feedback_session_id, references(:feedbacks_sessions, on_delete: :nothing)
    end

    create index(:call_logs, [:feedback_session_id])
  end
end
