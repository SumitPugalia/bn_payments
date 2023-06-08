defmodule Mix.Tasks.CorrectBuildingData do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Buildings.Building

  @shortdoc "Correct buildings related data"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    File.stream!("#{File.cwd!()}/priv/data/final_pune_buildings_v2.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&update_building_data/1)
  end

  def update_building_data({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def update_building_data({:ok, data}) do
    building_id = data |> Enum.at(0)

    attrs = %{
      "location" => fetch_location(data |> Enum.at(2)),
      "name" => data |> Enum.at(4)
    }

    building = Repo.get(Building, building_id)

    unless is_nil(building) do
      {_, _} = building |> Building.update_building(attrs)
      IO.puts("Building #{building.name} updated")
    end
  end

  def fetch_location(coordinates) do
    coordinates = coordinates |> String.split(",")
    coordinates = {String.to_float(Enum.at(coordinates, 0)), String.to_float(Enum.at(coordinates, 1))}
    %Geo.Point{coordinates: coordinates, srid: 4326}
  end
end
