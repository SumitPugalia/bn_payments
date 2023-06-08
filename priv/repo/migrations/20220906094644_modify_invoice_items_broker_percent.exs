defmodule BnApis.Repo.Migrations.ModifyInvoiceItemsBrokerPercent do
  use Ecto.Migration

  def change do
    alter table(:invoice_items) do
      modify(:brokerage_percent, :float)
      modify(:agreement_value, :bigint)
    end
  end
end
