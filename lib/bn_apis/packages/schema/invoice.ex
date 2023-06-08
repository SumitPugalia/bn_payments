defmodule BnApis.Packages.Invoice do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Packages.Payment
  alias BnApis.Packages.Invoice

  @derive Jason.Encoder
  schema "package_invoices" do
    field(:gst, :string)
    field(:gst_legal_name, :string)
    field(:gst_pan, :string)
    field(:gst_constitution, :string)
    field(:gst_address, :string)
    field(:is_gst_invoice, :boolean)
    field(:invoice_url, :string)

    belongs_to(:payment, Payment)
    timestamps()
  end

  @required [:payment_id, :is_gst_invoice, :invoice_url]
  @optional [:gst, :gst_legal_name, :gst_pan, :gst_constitution, :gst_address, :is_gst_invoice]

  @doc false
  def changeset(attrs) do
    %Invoice{}
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:payment_id)
    |> foreign_key_constraint(:payment_id)
  end

  @doc false
  def update_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, @optional ++ [:invoice_url])
  end
end
