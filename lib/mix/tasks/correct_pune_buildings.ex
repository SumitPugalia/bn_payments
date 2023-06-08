defmodule Mix.Tasks.CorrectPuneBuildings do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Buildings.Building

  @buildings_path ["pune_society_locality_data.csv"]

  @shortdoc "Correct buildings related data"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    @buildings_path
    |> Enum.each(&create_building/1)
  end

  def create_building(path) do
    File.stream!("#{File.cwd!()}/priv/data/#{path}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&create_building_data/1)
  end

  def create_building_data({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def create_building_data({:ok, data}) do
    id = data |> Enum.at(0)
    building = Repo.get(Building, id)

    attrs = %{
      "name" => data |> Enum.at(2),
      "display_address" => data |> Enum.at(3),
      "location" => fetch_location(data |> Enum.at(4)),
      "polygon_id" => BnApis.Places.Polygon.fetch_or_create_polygon(data |> Enum.at(5)).id
    }

    IO.puts(inspect(attrs))

    unless is_nil(building) do
      {_, _} = building |> Building.update_building(attrs)
      IO.puts("ALREADY PRESENT: Building #{data |> Enum.at(2)} updated")
    end
  end

  def fetch_location(coordinates) do
    coordinates = coordinates |> String.split(",")
    coordinates = {String.to_float(Enum.at(coordinates, 0)), String.to_float(Enum.at(coordinates, 1))}
    %Geo.Point{coordinates: coordinates, srid: 4326}
  end
end
