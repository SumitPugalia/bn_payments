defmodule BnApis.Repo.Migrations.UpdateLoanAmountFieldTypes do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      modify :loan_amount, :integer
    end
  end
end
