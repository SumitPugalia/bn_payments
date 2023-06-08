defmodule BnApis.Repo.Migrations.AddInvoiceUrlToMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:invoice_url, :string)
    end
  end
end
