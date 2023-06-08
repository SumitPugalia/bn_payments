defmodule BnApis.Repo.Migrations.AddIsGstInvoiceInMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:is_gst_invoice, :boolean, default: false)
    end
  end
end
