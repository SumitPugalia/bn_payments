defmodule Mix.Tasks.PopulateBillingCompanyData do
  use Mix.Task
  alias BnApis.Organizations.BrokerRole
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Accounts.Credential

  @path ["billing_company_data.csv"]

  @shortdoc "Populate Billing Companies Data in DB"
  def run(_) do
    Mix.Task.run("app.start", [])

    IO.puts("STARTING TO ADD BILLING COMPANIES DATA")
    # remove first line from csv file that contains headers
    @path
    |> Enum.each(&populate/1)

    IO.puts("BILLING COMPANIES DATA POPULATION COMPLETED")
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&populate_billing_company/1)
  end

  defp fetch_data(data, id), do: data |> Enum.at(id)

  defp parse_for_nil(_field = "", key), do: "EMPTY_" <> key

  defp parse_for_nil(field, _key), do: field

  defp refine_attrs(attrs) do
    name = Map.get(attrs, "name", "") |> parse_for_nil("name")
    address = Map.get(attrs, "address", "") |> parse_for_nil("address")
    place_of_supply = Map.get(attrs, "place_of_supply", "") |> parse_for_nil("place_of_supply")
    company_type = Map.get(attrs, "company_type", "") |> parse_for_nil("company_type")
    pan = Map.get(attrs, "pan", "") |> parse_for_nil("pan")
    rera_id = Map.get(attrs, "rera_id", "") |> parse_for_nil("rera_id")
    bill_to_state = Map.get(attrs, "bill_to_state", "") |> parse_for_nil("bill_to_state")
    bill_to_city = Map.get(attrs, "bill_to_city", "") |> parse_for_nil("bill_to_city")
    bill_to_pincode = Map.get(attrs, "bill_to_pincode", 0)

    Map.merge(attrs, %{
      "name" => name,
      "address" => address,
      "place_of_supply" => place_of_supply,
      "company_type" => company_type,
      "pan" => pan,
      "rera_id" => rera_id,
      "bill_to_state" => bill_to_state,
      "bill_to_city" => bill_to_city,
      "bill_to_pincode" => bill_to_pincode
    })
  end

  defp refine_bank_account(bank_account) do
    account_holder_name = Map.get(bank_account, "account_holder_name", "") |> parse_for_nil("account_holder_name")
    ifsc = Map.get(bank_account, "ifsc", "") |> parse_for_nil("ifsc")
    bank_account_type = Map.get(bank_account, "bank_account_type", "") |> parse_for_nil("bank_account_type")
    account_number = Map.get(bank_account, "account_number", "") |> parse_for_nil("account_number")

    confirm_account_number = Map.get(bank_account, "confirm_account_number", "") |> parse_for_nil("confirm_account_number")

    Map.merge(bank_account, %{
      "account_holder_name" => account_holder_name,
      "ifsc" => ifsc,
      "bank_account_type" => bank_account_type,
      "account_number" => account_number,
      "confirm_account_number" => confirm_account_number
    })
  end

  def populate_billing_company({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_billing_company({:ok, data}) do
    # Extract data from CSV
    user_id = fetch_data(data, 0)
    name = fetch_data(data, 1)
    address = fetch_data(data, 2)
    place_of_supply = fetch_data(data, 3)
    company_type = fetch_data(data, 4)
    email = fetch_data(data, 5)
    gst = fetch_data(data, 6)
    pan = fetch_data(data, 7)
    rera_id = fetch_data(data, 8)
    signature = fetch_data(data, 14)
    bill_to_state = fetch_data(data, 17)
    bill_to_pincode = fetch_data(data, 18)
    bill_to_city = fetch_data(data, 19)

    account_holder_name = fetch_data(data, 9)
    ifsc = fetch_data(data, 10)
    bank_account_type = fetch_data(data, 11)
    account_number = fetch_data(data, 12)
    confirm_account_number = fetch_data(data, 13)
    bank_name = fetch_data(data, 16)
    cancelled_cheque = fetch_data(data, 21)

    bank_account = %{
      "account_holder_name" => String.trim(account_holder_name),
      "ifsc" => String.trim(ifsc),
      "bank_account_type" => String.trim(bank_account_type),
      "account_number" => String.trim(account_number),
      "confirm_account_number" => String.trim(confirm_account_number),
      "bank_name" => String.trim(bank_name),
      "cancelled_cheque" => String.trim(cancelled_cheque)
    }

    bank_account = refine_bank_account(bank_account)

    attrs = %{
      "name" => String.trim(name),
      "address" => String.trim(address),
      "place_of_supply" => String.trim(place_of_supply),
      "company_type" => String.trim(company_type),
      "email" => String.trim(email),
      "gst" => String.trim(gst),
      "pan" => String.trim(pan),
      "rera_id" => String.trim(rera_id),
      "signature" => String.trim(signature),
      "bill_to_state" => String.trim(bill_to_state),
      "bill_to_pincode" => bill_to_pincode,
      "bill_to_city" => String.trim(bill_to_city),
      "bank_account" => bank_account
    }

    attrs = refine_attrs(attrs)

    broker_id = Credential.get_broker_id_from_uuid(String.trim(user_id))

    broker_id_exists? = not is_nil(broker_id)
    billing_company_exists? = not is_nil(BillingCompany.get_billing_company_from_repo_by_pan(pan))

    case {broker_id_exists?, billing_company_exists?} do
      {false, _} ->
        IO.inspect("Active broker id does not exists for user_id #{user_id}")

      {_, true} ->
        IO.inspect("Billing company with Name: #{name} and PAN: #{pan} already exists.")

      {true, false} ->
        with {:ok, _billing_company} <- BillingCompany.create(attrs, broker_id, BrokerRole.admin().id) do
          IO.inspect("Record with Name: #{name} and PAN: #{pan} added.")
        else
          {:error, changeset} ->
            IO.inspect("============== Error:  =============")
            IO.inspect("Issue while adding record with Name: #{name} and PAN: #{pan}, user_id: #{user_id}.")
            IO.inspect(changeset.errors)
        end
    end
  end
end
