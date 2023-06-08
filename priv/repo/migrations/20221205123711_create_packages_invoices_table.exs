defmodule BnApis.Repo.Migrations.CreatePackagesInvoicesTable do
  use Ecto.Migration

  def change do
    create table(:package_invoices) do
      add(:gst, :string)
      add(:gst_legal_name, :string)
      add(:gst_pan, :string)
      add(:gst_constitution, :string)
      add(:gst_address, :string)
      add(:is_gst_invoice, :boolean)
      add(:invoice_url, :string)
      add :payment_id, references(:payments, on_delete: :nothing)

      timestamps()
    end
  end
end
