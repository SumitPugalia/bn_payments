defmodule BnApis.Repo.Migrations.UpdateLoanAmountFieldType do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      modify :loan_amount, :integer
    end
  end
end
