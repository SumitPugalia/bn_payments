defmodule BnApis.Repo.Migrations.CreateProjectSalesCallLogs do
  use Ecto.Migration

  def change do
    create table(:project_sales_call_logs) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :timestamp, :naive_datetime
      add :user_id, references(:credentials, on_delete: :nothing)
      add :sales_person_id, references(:sales_persons, on_delete: :nothing)

      timestamps()
    end

    create index(:project_sales_call_logs, [:user_id])
    create index(:project_sales_call_logs, [:sales_person_id])
  end
end
