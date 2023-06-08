defmodule BnApis.Repo.Migrations.AddInvoiceUrlToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:invoice_pdf_url, :string)
    end

    alter table(:rewards_invoices) do
      add(:rewards_invoice_pdf_url, :string)
    end
  end
end
