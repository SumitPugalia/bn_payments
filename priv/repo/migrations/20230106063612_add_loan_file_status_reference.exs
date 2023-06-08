defmodule BnApis.Repo.Migrations.AddLoanFileStatusReference do
  use Ecto.Migration

  def change do
    alter table(:loan_files) do
      add(:latest_file_status_id, references(:loan_file_statuses))
      remove :status_id
    end
  end
end
