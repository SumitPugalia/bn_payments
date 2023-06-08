defmodule BnApis.Accounts.WhitelistedNumber do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Helpers.FormHelper
  alias BnApis.Accounts.WhitelistedNumber
  alias BnApis.Repo

  schema "whitelisted_numbers" do
    field :phone_number, :string
    field :country_code, :string, default: "+91"

    timestamps()
  end

  @doc false
  def changeset(whitelisted_number, attrs) do
    whitelisted_number
    |> cast(attrs, [:phone_number, :country_code])
    |> validate_required([:phone_number, :country_code])
    |> unique_constraint(:phone_number)
    |> FormHelper.validate_phone_number(:phone_number)
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_fetch_whitelisted_number(phone_number, country_code) do
    case fetch_whitelisted_number(phone_number, country_code) do
      nil ->
        create(phone_number, country_code)

      whitelisted_number ->
        {:ok, whitelisted_number}
    end
  end

  def create(phone_number, country_code) do
    %WhitelistedNumber{}
    |> WhitelistedNumber.changeset(%{phone_number: phone_number, country_code: country_code})
    |> Repo.insert()
  end

  @doc """
  1. Fetches active credential from phone number
  """
  def fetch_whitelisted_number(phone_number, country_code) do
    Repo.get_by(WhitelistedNumber, phone_number: phone_number, country_code: country_code)
  end

  def remove(phone_number, country_code) do
    case fetch_whitelisted_number(phone_number, country_code) do
      nil ->
        nil

      whitelisted_number ->
        Repo.delete(whitelisted_number)
    end
  end
end
