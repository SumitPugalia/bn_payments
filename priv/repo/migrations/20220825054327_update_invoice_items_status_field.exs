defmodule BnApis.Repo.Migrations.UpdateInvoiceItemsStatusField do
  use Ecto.Migration

  def change do
    drop_if_exists index(
                     :invoice_items,
                     [
                       :invoice_id,
                       :customer_name,
                       :unit_number,
                       :wing_name,
                       :building_name,
                       :status
                     ],
                     name: :unique_invoice_item_index
                   )

    alter table(:invoice_items) do
      remove(:status)
      add(:active, :boolean, default: true)
    end

    create(
      unique_index(
        :invoice_items,
        [:invoice_id, :customer_name, :unit_number, :wing_name, :building_name, :active],
        where: "active = true",
        name: :unique_active_invoice_items_index
      )
    )
  end
end
