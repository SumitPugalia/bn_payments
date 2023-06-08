defmodule BnApis.Repo.Migrations.CreateLoanFileStatuses do
  use Ecto.Migration

  def change do
    create table(:loan_file_statuses) do
      add(:status_id, :integer, null: false)
      add(:loan_file_id, references(:loan_files), null: false)
      timestamps()
    end
  end
end
