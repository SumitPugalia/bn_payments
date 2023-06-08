defmodule Mix.Tasks.PopulateTransactionBuildingLocalityId do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Transactions.Building
  alias BnApis.Places.Locality
  alias BnApis.Helpers.ExternalApiHelper

  @shortdoc "Populate Transaction Locality Place Id"
  def run(_) do
    Mix.Task.run("app.start", [])

    building_addresses_query()
    |> Enum.each(&fetch_and_update_place_id/1)

    building_with_locality_query()
    |> Enum.each(&update_place_id/1)
  end

  def building_addresses_query() do
    Building
    |> where([b], not is_nil(b.address) and is_nil(b.locality_id))
    |> select([b], [b.id, b.address])
    |> Repo.all()
  end

  def building_with_locality_query() do
    Building
    |> where([b], not is_nil(b.locality) and is_nil(b.locality_id))
    |> select([b], [b.id, b.locality])
    |> Repo.all()
  end

  def fetch_and_update_place_id([building_id, address]) do
    locality_name = locality_name_from_address(address)
    first_suggestion = ExternalApiHelper.predict_place(locality_name) |> Enum.at(0)

    create_and_update_locality(building_id, first_suggestion)
  end

  def update_place_id([building_id, locality_name]) do
    locality_name = locality_name_from_address(locality_name)
    first_suggestion = ExternalApiHelper.predict_place(locality_name) |> Enum.at(0)

    create_and_update_locality(building_id, first_suggestion)
  end

  def create_and_update_locality(building_id, suggestion) do
    unless is_nil(suggestion["description"]) do
      locality_attrs = %{
        name: suggestion["structured_formatting"]["main_text"],
        display_address: suggestion["description"],
        google_place_id: suggestion["place_id"]
      }

      {:ok, locality} = Locality.get_or_create_locality(locality_attrs)

      IO.puts("Updating building id: #{building_id} having locality_name \"#{suggestion["description"]}\" with locality_id: #{locality.id}")

      building = Building |> Repo.get(building_id)
      building |> Building.locality_id_changeset(locality.id) |> Repo.update()
    end
  end

  def locality_name_from_address(address) do
    address
    |> String.split(",")
    |> Enum.take(-4)
    |> Enum.join(",")
    |> String.trim()
  end
end
