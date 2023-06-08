defmodule BnApis.Repo.Migrations.AddParamsInInvoiceTable do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:total_payable_amount, :float)
      add(:tds_percentage, :float)
    end
  end
end
