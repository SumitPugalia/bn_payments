defmodule BnApis.Repo.Migrations.AddUniqueConstraintForRewardsInvoiceTable do
  use Ecto.Migration

  def change do
    create(
      unique_index(
        :rewards_invoices,
        [:invoice_id, :invoice_amount],
        name: :unique_invoice_for_rewards_invoice_index
      )
    )
  end
end
