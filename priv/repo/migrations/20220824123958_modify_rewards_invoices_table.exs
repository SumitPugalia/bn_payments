defmodule BnApis.Repo.Migrations.ModifyRewardsInvoicesTable do
  use Ecto.Migration

  def change do
    rename table("rewards_invoices"), :rewards_invoice_pdf_url, to: :booking_invoice_pdf_url
  end
end
