defmodule BnApis.Invoices.InvoiceNumber do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo

  alias BnApis.Invoices.InvoiceNumber
  alias BnApis.Places.City

  @city_codes %{
    1 => "MUM",
    2 => "BEN",
    3 => "GUR",
    11 => "JAI",
    37 => "PUN"
  }

  schema "invoice_numbers" do
    field(:invoice_number, :string)

    field(:city_code, :string)

    field(:invoice_type, :string)
    field(:invoice_reference_id, :integer)

    field(:year, :integer)
    field(:month, :integer)
    field(:sequence, :integer)

    belongs_to(:city, City)

    timestamps()
  end

  @required [
    :invoice_number,
    :city_code,
    :year,
    :month,
    :sequence,
    :invoice_type,
    :invoice_reference_id,
    :city_id
  ]
  @optional []

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:invoice_number)
    |> unique_constraint(:sequence, name: :invoice_number_sequence_index)
    |> unique_constraint(:invoice_reference_id, name: :invoice_reference_id_index)
  end

  def get_invoice_number(invoice_type, invoice_reference_id) do
    Repo.get_by(InvoiceNumber, invoice_type: invoice_type, invoice_reference_id: invoice_reference_id)
  end

  def find_or_create_invoice_number(params, timestamp) do
    invoice_number = get_invoice_number(params[:invoice_type], params[:invoice_reference_id])

    if not is_nil(invoice_number),
      do: invoice_number,
      else: create_invoice_number(params, timestamp)
  end

  def create_invoice_number(params, timestamp) do
    {:ok, datetime} = DateTime.from_unix(timestamp)

    datetime
    |> Timex.Timezone.convert("UTC")
    |> Timex.Timezone.convert("Asia/Kolkata")

    year = datetime.year
    month = datetime.month

    city_code = @city_codes[params[:city_id]]

    latest_sequenced_invoice_number =
      get_latest_sequenced_invoice_number(
        city_code,
        params[:invoice_type],
        year,
        month
      )

    sequence =
      if not is_nil(latest_sequenced_invoice_number) do
        latest_sequenced_invoice_number.sequence + 1
      else
        1
      end

    # "MUM OS_AP 22 07 0001"
    invoice_number = "#{city_code}_#{params[:invoice_type]}_#{year}_#{month}_#{sequence}"

    ch =
      InvoiceNumber.changeset(%InvoiceNumber{}, %{
        city_code: city_code,
        city_id: params[:city_id],
        invoice_reference_id: params[:invoice_reference_id],
        invoice_type: params[:invoice_type],
        year: year,
        month: month,
        sequence: sequence,
        invoice_number: invoice_number
      })

    Repo.insert!(ch)
  end

  def get_latest_sequenced_invoice_number(city_code, invoice_type, year, month) do
    InvoiceNumber
    |> where([inv], inv.city_code == ^city_code)
    |> where([inv], inv.invoice_type == ^invoice_type)
    |> where([inv], inv.year == ^year)
    |> where([inv], inv.month == ^month)
    |> order_by(desc: :sequence)
    |> limit(1)
    |> Repo.one()
  end
end
