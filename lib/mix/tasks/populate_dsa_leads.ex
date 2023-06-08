defmodule Mix.Tasks.PopulateDsaLeads do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.Credential
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Homeloan.LeadStatusNote
  alias BnApis.Homeloan.LeadStatus

  def run(_) do
    Mix.Task.run("app.start", [])
    # remaining_digits = Stream.repeatedly(fn -> Enum.random(0000000..9999999) end) |> Stream.uniq |> Enum.take(50000)
    File.stream!("#{File.cwd!()}/priv/data/dsa_leads.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.with_index()
    |> Enum.map(&create_leads/1)
  end

  def create_leads({{:error, data}, _index}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def create_leads({{:ok, data}, _index}) do
    lead_id = data |> Enum.at(0)
    inserted_at = data |> Enum.at(5)

    cond do
      lead_id == "" and inserted_at != "" -> create_dsa_leads(data)
      true -> nil
    end
  end

  def format_string(amount) do
    amount = if String.contains?(amount, "."), do: String.split(amount, ".") |> Enum.at(0), else: amount
    amount = if String.contains?(amount, "-"), do: nil, else: amount
    if is_nil(amount) or amount == "", do: nil, else: String.replace(amount, ",", "") |> String.to_integer()
  end

  def create_dsa_leads(data) do
    name = data |> Enum.at(1)
    broker_name = data |> Enum.at(3)
    sanctioned_amount = data |> Enum.at(6) |> IO.inspect() |> format_string()
    disbursement_amount = data |> Enum.at(7) |> format_string()
    random_date = :rand.uniform(28)
    inserted_at = data |> Enum.at(5)
    inserted_at_arr = String.split(inserted_at, "-")
    inserted_at_month = Enum.at(inserted_at_arr, 0)
    inserted_at_year = Enum.at(inserted_at_arr, 1) |> String.to_integer()

    bank_name = data |> Enum.at(8)

    month_map = %{
      "Jan" => 01,
      "Feb" => 02,
      "Mar" => 03,
      "Apr" => 04,
      "May" => 05,
      "Jun" => 06,
      "Jul" => 07,
      "Aug" => 08,
      "Sep" => 09,
      "Oct" => 10,
      "Nov" => 11,
      "Dec" => 12
    }

    inserted_at_month = month_map[inserted_at_month]

    dt = %DateTime{
      year: 2000 + inserted_at_year,
      month: inserted_at_month,
      day: random_date,
      zone_abbr: "UTC",
      hour: 23,
      minute: 0,
      second: 7,
      microsecond: {0, 0},
      utc_offset: 0,
      std_offset: 0,
      time_zone: "Etc/UTC"
    }

    naive_datetime = DateTime.to_naive(dt)

    lead_creation_date = DateTime.to_unix(dt)
    broker_id = whitelist_broker_if_not_whitelisted(broker_name)
    IO.inspect("Adding lead #{name}")

    lead_params = %{
      "name" => name,
      "broker_id" => broker_id,
      "employee_credentials_id" => nil,
      "employment_type" => 1,
      "lead_creation_date" => lead_creation_date,
      "bank_name" => bank_name,
      "country_id" => 1,
      "loan_amount" => sanctioned_amount,
      "inserted_at" => naive_datetime
    }

    homeloan_lead =
      %Lead{}
      |> cast(lead_params, [:name, :broker_id, :employment_type, :lead_creation_date, :bank_name, :country_id, :loan_amount, :inserted_at])
      |> IO.inspect()
      |> Repo.insert!()

    latest_lead_status =
      LeadStatus.create_lead_status!(
        homeloan_lead,
        6,
        [1, 2],
        disbursement_amount,
        nil,
        nil
      )

    note = "Disbursement of #{disbursement_amount} done"

    LeadStatusNote.create_lead_status_note!(
      note,
      latest_lead_status.id,
      nil
    )
  end

  def whitelist_broker_if_not_whitelisted(broker_name) do
    brokers =
      Broker
      |> where(name: ^broker_name)
      |> Repo.all()

    case length(brokers) do
      0 ->
        whitelist_broker(broker_name)

      _ ->
        List.first(brokers).id
    end
  end

  def whitelist_broker(broker_name) do
    default_start_number = "3"
    remaining_digits = Enum.random(00_00_00_000..99_99_99_999)

    phone_number = "#{default_start_number}#{remaining_digits}"

    broker_params = %{
      "name" => broker_name,
      "role_type_id" => 1,
      # prod************************ TO BE CHANGED FOR STAG AND PROD****************************
      "polygon_id" => 54
    }

    IO.inspect("Adding broker #{broker_name}")

    {:ok, broker} =
      %Broker{}
      |> Broker.changeset(broker_params)
      |> Repo.insert()

    credential_params = %{
      "phone_number" => phone_number,
      # prod************************ TO BE CHANGED FOR STAG AND PROD****************************
      "organization_id" => 24990,
      "broker_id" => broker.id,
      "profile_type_id" => 1
    }

    %Credential{} |> cast(credential_params, [:phone_number, :organization_id, :broker_id, :profile_type_id]) |> Repo.insert!()
    broker.id
  end
end
