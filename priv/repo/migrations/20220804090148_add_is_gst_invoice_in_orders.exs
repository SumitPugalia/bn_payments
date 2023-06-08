defmodule BnApis.Repo.Migrations.AddIsGstInvoiceInOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:is_gst_invoice, :boolean, default: false)
    end
  end
end
