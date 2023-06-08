defmodule BnApis.Repo.Migrations.CreateInvoicingItemsTable do
  use Ecto.Migration

  def change do
    create table(:invoice_items) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:customer_name, :string, null: false)
      add(:unit_number, :string, null: false)
      add(:wing_name, :string, null: false)
      add(:building_name, :string, null: false)
      add(:status, :string, null: false)
      add(:agreement_value, :integer)
      add(:brokerage_percent, :integer)
      add(:brokerage_amount, :integer)
      add(:invoice_id, references(:invoices))

      timestamps()
    end

    create(
      unique_index(
        :invoice_items,
        [:invoice_id, :customer_name, :unit_number, :wing_name, :building_name, :status],
        name: :unique_invoice_item_index
      )
    )
  end
end
