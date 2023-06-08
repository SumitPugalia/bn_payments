defmodule BnApis.Repo.Migrations.ModifyLoanInsuranceDoneInLoanFiles do
  use Ecto.Migration

  def change do
    alter table(:loan_files) do
      modify(:loan_insurance_done, :boolean, default: nil)
    end
  end
end
