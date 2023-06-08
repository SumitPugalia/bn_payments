defmodule BnApis.Repo.Migrations.AddCommissionPercentageInLoanDisbursement do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add(:commission_percentage, :float)
    end
  end
end
