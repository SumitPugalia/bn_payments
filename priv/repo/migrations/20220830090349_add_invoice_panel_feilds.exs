defmodule BnApis.Repo.Migrations.AddInvoicePanelFeilds do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:proof_url, :string)
      add(:change_notes, :string)
      add(:is_advance_payment, :boolean, default: false)
      add(:payment_utr, :string)
    end
  end
end
