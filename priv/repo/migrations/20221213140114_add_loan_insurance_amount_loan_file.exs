defmodule BnApis.Repo.Migrations.AddLoanInsuranceAmountLoanFile do
  use Ecto.Migration

  def change do
    alter table(:loan_files) do
      add(:loan_insurance_amount, :bigint)
    end
  end
end
