defmodule BnApis.Stories.Schema.InvoiceItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.Schema.Invoice

  schema "invoice_items" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:customer_name, :string)
    field(:unit_number, :string)
    field(:wing_name, :string)
    field(:building_name, :string)
    field(:agreement_value, :integer)
    field(:brokerage_percent, :float)
    field(:brokerage_amount, :integer)
    field(:active, :boolean, default: true)

    belongs_to(:invoice, Invoice)

    timestamps()
  end

  @fields [
    :uuid,
    :customer_name,
    :unit_number,
    :wing_name,
    :building_name,
    :active,
    :agreement_value,
    :brokerage_percent,
    :brokerage_amount,
    :invoice_id
  ]

  @required_fields [
    :customer_name,
    :unit_number,
    :wing_name,
    :building_name,
    :active,
    :agreement_value,
    :brokerage_amount
  ]

  @duplicate_invoice_error_message "An invoice item with same customer name, unit number, wing name, and building name already exists for the invoice"

  @doc false
  def changeset(invoice_item, attrs \\ %{}, cast_assoc \\ false) do
    required = if cast_assoc, do: [], else: [:invoice_id]

    invoice_item
    |> cast(attrs, @fields ++ required)
    |> validate_required(@required_fields ++ required)
    |> unique_constraint(:invoice_id,
      name: :unique_active_invoice_items_index,
      message: @duplicate_invoice_error_message
    )
    |> foreign_key_constraint(:invoice_id)
  end
end
