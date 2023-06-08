defmodule BnApis.Repo.Migrations.AddFundAccountIdToBillingCompany do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      add :razorpay_fund_account_id, :string
    end
  end
end
