defmodule BnApis.Repo.Migrations.AddFieldsInLoanDisbursement do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add(:otc_cleared, :boolean, default: false)
      add(:pdd_cleared, :boolean, default: false)
      add(:lan, :integer)
      add(:disbursement_type, :string)
      add(:document_url, :string)

      add(:invoice_id, references(:invoices))
    end
  end
end
