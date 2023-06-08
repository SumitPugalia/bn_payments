defmodule BnApis.Repo.Migrations.CreateCallLogsCallStatuses do
  use Ecto.Migration

  def change do
    create table(:call_logs_call_statuses, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:call_logs_call_statuses, [:name])
  end
end
