defmodule BnApis.Repo.Migrations.AddColumnInTransactionData do
  use Ecto.Migration

  def change do
    alter table(:transactions_data) do
      add :status_id, references(:transactions_statuses, on_delete: :nothing)
      add :assignee_id, references(:employees_credentials, on_delete: :nothing)
    end

    # User can have only 1 document as in-process at a time.
    create unique_index(:transactions_data, [:assignee_id],
             where: "status_id = 2",
             name: :td_in_process_uniq_index
           )
  end
end
