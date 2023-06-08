defmodule BnApis.Repo.Migrations.AddNoteInLoanFileStatuses do
  use Ecto.Migration

  def change do
    alter table(:loan_file_statuses) do
      add(:note, :text)
    end
  end
end
