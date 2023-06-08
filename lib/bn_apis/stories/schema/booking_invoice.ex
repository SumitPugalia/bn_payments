defmodule BnApis.Stories.Schema.BookingInvoice do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Stories.Schema.Invoice

  schema "booking_invoices" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:has_gst, :boolean, default: false)
    field(:booking_invoice_pdf_url, :string)
    field(:invoice_amount, :integer)

    belongs_to(:invoice, Invoice)

    timestamps()
  end

  @fields [
    :uuid,
    :has_gst,
    :invoice_amount,
    :invoice_id,
    :booking_invoice_pdf_url
  ]

  @required_fields [
    :has_gst,
    :invoice_amount,
    :invoice_id
  ]

  @duplicate_booking_invoice_message "A booking invoice already exits for the invoice."

  @doc false
  def changeset(booking_invoice, attrs \\ %{}) do
    booking_invoice
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:invoice_id,
      name: :unique_booking_invoice_for_brokerage_invoice_index,
      message: @duplicate_booking_invoice_message
    )
    |> foreign_key_constraint(:invoice_id)
  end
end
