defmodule BnApis.Repo.Migrations.CreateCallLogs do
  use Ecto.Migration

  def change do
    create table(:call_logs) do
      add :phone_number, :string
      add :call_log_uuid, :uuid
      add :time_of_call, :naive_datetime
      add :call_duration, :integer
      add :sim_id, :string
      add :call_status_id, references(:call_logs_call_statuses, on_delete: :nothing)
      add :user_id, references(:credentials, on_delete: :nothing)
      add :is_professional, :boolean, default: false, null: false

      timestamps()
    end

    create index(:call_logs, [:call_status_id])
    create index(:call_logs, [:user_id])
    create unique_index(:call_logs, [:call_log_uuid, :user_id], name: :call_log_uuid_index)
  end
end
