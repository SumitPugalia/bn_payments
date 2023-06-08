defmodule BnApis.Repo.Migrations.AddBranchLocationLoanFiles do
  use Ecto.Migration

  def change do
    alter table(:loan_files) do
      add(:branch_location, :string)
      add(:original_agreement_doc_url, :string)
      add(:loan_insurance_done, :boolean, default: false)
    end
  end
end
