defmodule BnApis.Repo.Migrations.AddInvoiceUrlInLd do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add :invoice_pdf_url, :string
    end
  end
end
