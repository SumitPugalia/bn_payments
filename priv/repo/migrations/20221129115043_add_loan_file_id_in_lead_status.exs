defmodule BnApis.Repo.Migrations.AddLoanFileIdInLeadStatus do
  use Ecto.Migration

  def change do
    alter table(:homeloan_lead_statuses) do
      add(:loan_file_id, references(:loan_files))
    end
  end
end
