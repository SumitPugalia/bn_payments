defmodule BnApis.Repo.Migrations.AddLoanAmountToLeadsTable do
  use Ecto.Migration

  def change do
    alter table(:homeloan_leads) do
      add :loan_amount, :float
    end
  end
end
