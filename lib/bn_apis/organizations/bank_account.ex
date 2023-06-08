defmodule BnApis.Organizations.BankAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Organizations.BankAccount
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Helpers.{ExternalApiHelper, S3Helper, ApplicationHelper}

  schema "bank_accounts" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:account_holder_name, :string)
    field(:ifsc, :string)
    # String Enum -> ["Savings", "Current"]
    field(:bank_account_type, :string)
    field(:account_number, :string)
    field(:confirm_account_number, :string)
    field(:bank_name, :string)
    field(:cancelled_cheque, :string)
    field(:active, :boolean, default: true)

    belongs_to(:billing_company, BillingCompany)

    timestamps()
  end

  @savings_account "Savings"
  @current_account "Current"
  @imgix_domain ApplicationHelper.get_imgix_domain()

  @fields [
    :uuid,
    :account_holder_name,
    :ifsc,
    :bank_account_type,
    :account_number,
    :confirm_account_number,
    :bank_name,
    :cancelled_cheque,
    :billing_company_id,
    :active
  ]

  @required_fields [
    :account_holder_name,
    :ifsc,
    :bank_account_type,
    :account_number,
    :confirm_account_number,
    :billing_company_id
  ]

  def changeset(bank_account, attrs \\ %{}) do
    bank_account
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_change(:bank_account_type, &validate_bank_account_type/2)
    |> validate_change(:ifsc, &validate_ifsc/2)
    |> validate_account_number()
    |> foreign_key_constraint(:billing_company_id)
    |> unique_constraint(:billing_company_id,
      name: :unique_bank_account_billing_company_index,
      message: "Same bank account with the billing company already exists."
    )
    |> format_changeset_response()
  end

  def new(attrs), do: changeset(%__MODULE__{}, attrs)

  def add_bank_account_for_company(_billing_company_id, nil), do: {:ok, nil}

  def add_bank_account_for_company(
        billing_company_id,
        params = %{
          "account_holder_name" => account_holder_name,
          "ifsc" => ifsc,
          "bank_account_type" => bank_account_type,
          "account_number" => account_number,
          "confirm_account_number" => confirm_account_number
        }
      ) do
    bank_name = Map.get(params, "bank_name")
    cancelled_cheque = Map.get(params, "cancelled_cheque")

    ifsc = String.trim(ifsc)
    bank_account_type = String.trim(bank_account_type)
    account_number = String.trim(account_number)
    confirm_account_number = String.trim(confirm_account_number)

    %BankAccount{}
    |> changeset(%{
      account_holder_name: account_holder_name,
      ifsc: ifsc,
      bank_account_type: bank_account_type,
      account_number: account_number,
      confirm_account_number: confirm_account_number,
      bank_name: bank_name,
      cancelled_cheque: cancelled_cheque,
      billing_company_id: billing_company_id
    })
    |> case do
      {:ok, changeset} ->
        Repo.insert(changeset)
        |> case do
          {:ok, bank_account} ->
            {:ok, create_bank_account_map(bank_account)}

          {:error, changeset} ->
            {:error, changeset}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def add_bank_account_for_company(_billing_company_id, _params), do: {:error, "Invalid bank account params."}

  def update_bank_account(nil, _billing_company_id), do: {:ok, nil}

  def update_bank_account(
        params = %{
          "account_holder_name" => account_holder_name,
          "ifsc" => ifsc,
          "bank_account_type" => bank_account_type,
          "account_number" => account_number,
          "confirm_account_number" => confirm_account_number
        },
        billing_company_id
      ) do
    id = Map.get(params, "id", nil)
    bank_name = Map.get(params, "bank_name")
    cancelled_cheque = Map.get(params, "cancelled_cheque")
    active = Map.get(params, "active")

    ifsc = String.trim(ifsc)
    bank_account_type = String.trim(bank_account_type)
    account_number = String.trim(account_number)
    confirm_account_number = String.trim(confirm_account_number)

    bank_account = fetch_bank_account(id)

    cond do
      is_nil(bank_account) ->
        create_or_throw_error_for_bank_account(id, params, billing_company_id)

      bank_account ->
        bank_account
        |> changeset(%{
          account_holder_name: account_holder_name,
          ifsc: ifsc,
          bank_account_type: bank_account_type,
          account_number: account_number,
          confirm_account_number: confirm_account_number,
          bank_name: bank_name,
          cancelled_cheque: cancelled_cheque,
          billing_company_id: billing_company_id,
          active: active
        })
        |> case do
          {:ok, changeset} ->
            Repo.update(changeset)

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  def update_bank_account(_params, _billing_company_id), do: {:error, "Invalid bank account params."}

  def get_bank_account_types() do
    [@savings_account, @current_account]
  end

  ## Private APIs

  defp format_changeset_response(%Ecto.Changeset{valid?: true} = changeset), do: {:ok, changeset}

  defp format_changeset_response(changeset), do: {:error, changeset}

  defp fetch_bank_account(nil), do: nil
  defp fetch_bank_account(id), do: Repo.get_by(BankAccount, id: id)

  defp create_or_throw_error_for_bank_account(nil, params, billing_company_id),
    do: add_bank_account_for_company(billing_company_id, params)

  defp create_or_throw_error_for_bank_account(_id, _params, _billing_company_id), do: {:error, "Bank Account not found"}

  defp validate_bank_account_type(:bank_account_type, bank_account_type) do
    valid_bank_account_types = [@savings_account, @current_account]

    if not Enum.member?(valid_bank_account_types, bank_account_type) do
      [bank_account_type: "Bank Account Type is not valid."]
    else
      []
    end
  end

  defp validate_ifsc(:ifsc, ifsc) do
    invalid_ifsc_length? = not (String.length(ifsc) == 11)
    {status, _response} = ExternalApiHelper.validate_ifsc(ifsc)
    invalid_ifsc? = not validate_ifsc_response_status(status)

    case {invalid_ifsc_length?, invalid_ifsc?} do
      {true, _} ->
        [ifsc: "Ifsc code is of an invalid length."]

      {_, true} ->
        [ifsc: "Ifsc code is invalid."]

      {_, _} ->
        []
    end
  end

  defp validate_ifsc_response_status(200), do: true

  defp validate_ifsc_response_status(404), do: false

  defp validate_ifsc_response_status(_), do: true

  defp validate_account_number(changeset) do
    account_number = get_field(changeset, :account_number)
    confirm_account_number = get_field(changeset, :confirm_account_number)

    if account_number === confirm_account_number do
      changeset
    else
      add_error(changeset, :account_number, "Account_number and confirm_account_number are not same.")
    end
  end

  defp parse_cancelled_cheque(nil), do: nil

  defp parse_cancelled_cheque(cancelled_cheque) do
    String.contains?(cancelled_cheque, @imgix_domain)
    |> case do
      true ->
        cancelled_cheque

      false ->
        S3Helper.get_imgix_url(cancelled_cheque)
    end
  end

  def create_bank_account_map(nil), do: nil

  def create_bank_account_map(bank_account) do
    %{
      "uuid" => bank_account.uuid,
      "id" => bank_account.id,
      "account_holder_name" => bank_account.account_holder_name,
      "ifsc" => bank_account.ifsc,
      "bank_account_type" => bank_account.bank_account_type,
      "account_number" => bank_account.account_number,
      "confirm_account_number" => bank_account.confirm_account_number,
      "bank_name" => bank_account.bank_name,
      "cancelled_cheque" => parse_cancelled_cheque(bank_account.cancelled_cheque),
      "billing_company_id" => bank_account.billing_company_id,
      "active" => bank_account.active
    }
  end
end
