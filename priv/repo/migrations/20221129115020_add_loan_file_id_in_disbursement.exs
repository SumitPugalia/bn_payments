defmodule BnApis.Repo.Migrations.AddLoanFileIdInDisbursement do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add(:loan_file_id, references(:loan_files))
      add(:otc_pdd_proof_doc, :string)
    end
  end
end
