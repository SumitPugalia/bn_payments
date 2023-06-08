defmodule BnApis.Accounts.WhitelistedBrokerInfo do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Helpers.FormHelper
  alias BnApis.Accounts.{WhitelistedBrokerInfo, EmployeeCredential}
  alias BnApis.Repo

  schema "whitelisted_brokers_info" do
    field :phone_number, :string
    field :country_code, :string, default: "+91"
    field :organization_name, :string
    field :broker_name, :string
    field :polygon_uuid, :string
    field :firm_address, :string
    field :place_id, :string
    field :assign_to, :string

    belongs_to :created_by, EmployeeCredential

    timestamps()
  end

  @fields [
    :phone_number,
    :country_code,
    :organization_name,
    :broker_name,
    :polygon_uuid,
    :firm_address,
    :created_by_id,
    :place_id,
    :assign_to
  ]
  @required_fields [:phone_number, :organization_name, :broker_name, :polygon_uuid, :created_by_id, :assign_to]

  @doc false
  def changeset(whitelisted_number, attrs, exclude_required \\ []) do
    whitelisted_number
    |> cast(attrs, @fields)
    |> validate_required(@required_fields -- exclude_required)
    |> FormHelper.validate_phone_number(:phone_number)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_fetch_whitelisted_broker(params = %{"country_code" => country_code, "phone_number" => phone_number}) do
    case fetch_whitelisted_number(phone_number, country_code) do
      nil ->
        %WhitelistedBrokerInfo{}
        |> WhitelistedBrokerInfo.changeset(params)
        |> Repo.insert()

      whitelisted_number_info ->
        {:ok, whitelisted_number_info}
    end
  end

  @doc """
  1. Fetches active credential from phone number
  """
  def fetch_whitelisted_number(phone_number, country_code) do
    WhitelistedBrokerInfo
    |> where([wb], wb.phone_number == ^phone_number and wb.country_code == ^country_code)
    |> order_by(desc: :updated_at)
    |> limit(1)
    |> Repo.one()
  end

  def create(params) do
    %WhitelistedBrokerInfo{}
    |> WhitelistedBrokerInfo.changeset(params)
    |> Repo.insert()
  end

  def create(params, true = _from_script?) do
    %WhitelistedBrokerInfo{}
    |> WhitelistedBrokerInfo.changeset(params, [:polygon_uuid, :created_by_id, :assign_to])
    |> Repo.insert()
  end

  def create(params, false = _from_script?), do: create(params)
end
