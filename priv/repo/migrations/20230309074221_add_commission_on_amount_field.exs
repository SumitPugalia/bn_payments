defmodule BnApis.Repo.Migrations.AddCommissionOnAmountField do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :gst_filling_status, :boolean, default: false
    end

    alter table(:loan_disbursements) do
      add :commission_applicable_amount, :integer
      add :commission_applicable_on, :string
    end
  end
end
