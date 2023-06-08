defmodule BnApis.Cabs.Operator do
  use Ecto.Schema
  import Ecto.Changeset
  alias BnApis.Cabs.Operator
  alias BnApis.Repo

  schema "cab_operators" do
    field :name, :string
    field :business_name, :string
    field :owner_name, :string
    field :contact_number, :string
    field :aadhar_card, :string
    field :resident_address, :string
    field :office_address, :string
    field :gst, :string
    field :pan, :string
    field :bank_name, :string
    field :account_number, :string
    field :ifsc, :string
    field :commission_percentage, :string
    field :is_deleted, :boolean, default: false

    timestamps()
  end

  @required [:name]
  @optional [
    :business_name,
    :owner_name,
    :contact_number,
    :aadhar_card,
    :resident_address,
    :office_address,
    :gst,
    :pan,
    :bank_name,
    :account_number,
    :ifsc,
    :commission_percentage,
    :is_deleted
  ]

  @doc false
  def changeset(operator, attrs) do
    operator
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name)
  end

  def create!(params) do
    %Operator{}
    |> Operator.changeset(params)
    |> Repo.insert!()
  end

  def update!(operator, params) do
    operator
    |> Operator.changeset(params)
    |> Repo.update!()
  end

  def get_data(operator) do
    %{
      "id" => operator.id,
      "name" => operator.name,
      "business_name" => operator.business_name,
      "owner_name" => operator.owner_name,
      "contact_number" => operator.contact_number,
      "aadhar_card" => operator.aadhar_card,
      "resident_address" => operator.resident_address,
      "office_address" => operator.office_address,
      "gst" => operator.gst,
      "pan" => operator.pan,
      "bank_name" => operator.bank_name,
      "account_number" => operator.account_number,
      "ifsc" => operator.ifsc,
      "commission_percentage" => operator.commission_percentage,
      "created_at" => operator.inserted_at,
      "is_deleted" => operator.is_deleted
    }
  end
end
