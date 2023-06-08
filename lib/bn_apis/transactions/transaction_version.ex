defmodule BnApis.Transactions.TransactionVersion do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Transactions.Transaction
  alias BnApis.Transactions.Building
  alias BnApis.Accounts.EmployeeCredential

  schema "transactions_versions" do
    field :version_id, :integer
    field :flat_no, :string
    field :floor_no, :integer
    field :area, :decimal
    field :price, :integer
    field :rent, :integer
    # in months
    field :tenure_for_rent, :integer
    # "rent/resale"
    field :transaction_type, :string
    field :registration_date, :naive_datetime

    belongs_to :edited_by, EmployeeCredential
    belongs_to :transaction, Transaction
    belongs_to :transaction_building, Building

    timestamps()
  end

  @required [:transaction_id, :edited_by_id]
  @fields @required ++
            [
              :version_id,
              :flat_no,
              :floor_no,
              :area,
              :transaction_type,
              :price,
              :rent,
              :tenure_for_rent,
              :transaction_building_id,
              :registration_date
            ]

  @doc false
  def changeset(transaction_version, attrs) do
    transaction_version
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end
end
