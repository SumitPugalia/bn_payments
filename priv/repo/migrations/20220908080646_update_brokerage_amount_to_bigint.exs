defmodule BnApis.Repo.Migrations.UpdateBrokerageAmountToBigint do
  use Ecto.Migration

  def change do
    alter table(:invoice_items) do
      modify(:brokerage_amount, :bigint)
    end
  end
end
