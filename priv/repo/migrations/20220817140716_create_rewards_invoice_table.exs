defmodule BnApis.Repo.Migrations.CreateRewardsInvoiceTable do
  use Ecto.Migration

  def change do
    create table(:rewards_invoices) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:has_gst, :boolean, default: false)
      add(:invoice_amount, :integer)
      add(:invoice_id, references(:invoices))

      timestamps()
    end
  end
end
