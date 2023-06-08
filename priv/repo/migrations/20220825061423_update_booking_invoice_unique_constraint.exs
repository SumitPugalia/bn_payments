defmodule BnApis.Repo.Migrations.UpdateBookingInvoiceUniqueConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists index(:booking_invoices, [:invoice_id, :invoice_amount],
                     name: :unique_invoice_for_rewards_invoice_index
                   )

    create(
      unique_index(
        :booking_invoices,
        [:invoice_id],
        name: :unique_booking_invoice_for_brokerage_invoice_index
      )
    )
  end
end
