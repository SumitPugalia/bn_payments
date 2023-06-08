defmodule Mix.Tasks.PopulateBrokerLocality do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Organizations.Broker
  alias BnApis.Places.Polygon

  @path ["broker_locality.csv"]

  @shortdoc "Populate brokers locality"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    @path
    |> Enum.each(&populate/1)
  end

  def populate(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&populate_broker_locality/1)
  end

  def populate_broker_locality({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_broker_locality({:ok, data}) do
    user_map = %{user_id: 291, user_type: "employee"}
    phone_number = data |> Enum.at(0)
    polygon_id = data |> Enum.at(1)
    polygon_id = if polygon_id == "", do: 37, else: polygon_id |> String.to_integer()
    polygon = Polygon.fetch_from_id(polygon_id)

    attrs = %{
      polygon_id: polygon_id,
      operating_city: polygon.city_id
    }

    credential = Accounts.get_active_credential_by_phone(phone_number, "+91")

    unless is_nil(credential) do
      Broker |> Repo.get(credential.broker_id) |> Broker.update(attrs, user_map)
      IO.puts("Broker with #{phone_number} updated")
    end
  end
end
