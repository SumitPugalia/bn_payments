defmodule BnApis.Repo.Migrations.AddInvoiceUrlToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:invoice_url, :string)
    end
  end
end
