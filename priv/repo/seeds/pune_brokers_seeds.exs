defmodule BnApis.Seeder.BrokerUniverse do

  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Contacts.BrokerUniverse

  @doc """
  Columns:
  1. account_id,
  2. name,
  3. phone_number,
  4. organization_name,
  5. locality,
  6. property_count
  """
  def seed_data() do
    File.stream!("priv/repo/seeds/pune_brokers.csv")
      |> CSV.decode
      |> Enum.to_list
      |> Enum.map(&create_broker_universe_struct/1)
      |> Enum.reject(&is_nil/1)
      |> (&(Repo.insert_all(BrokerUniverse, &1, on_conflict: :nothing))).()
  end

  def create_broker_universe_struct({:error, _data}), do: nil
  def create_broker_universe_struct({:ok, data}) do
    [_account_id, name, phone, organization_name, _locality, _property_count] = data
    {:ok, phone_number} = ExPhoneNumber.parse(phone, "IN")
    if (ExPhoneNumber.is_valid_number?(phone_number)) do
      phone_number_str = phone_number.national_number |> to_string
      query = BrokerUniverse
        |> where(phone_number: ^phone_number_str)

      case query |> Repo.one do
        nil ->
          %{
            name: name,
            phone_number: phone_number_str,
            # locality: locality,
            organization_name: organization_name,
            inserted_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now |> NaiveDateTime.truncate(:second)
          }
        _broker ->
          nil
      end
    end
  end
end
