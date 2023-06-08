defmodule Mix.Tasks.PopulateBuildingData do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Buildings.Building
  alias BnApis.Helpers.ApplicationHelper

  @buildings_path ["hiranandani_estate_buildings.csv"]
  @shortdoc "Creates buildings related data"
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
    name = data |> Enum.at(0)
    location = fetch_location(data |> Enum.at(2))
    polygon_name = data |> Enum.at(3)
    city_id = ApplicationHelper.get_city_id_from_name(data |> Enum.at(4))

    attrs = %{
      "name" => name,
      "display_address" => data |> Enum.at(1),
      "location" => location,
      "polygon_id" => BnApis.Places.Polygon.fetch_or_create_polygon(polygon_name, city_id).id
    }

    if Building |> where(location: ^location) |> Repo.aggregate(:count, :id) == 0 do
      {:ok, _building} = Building.create_building(attrs)
      IO.puts("Building #{name} created")
    else
      building = Building |> where(location: ^location) |> Repo.all() |> hd

      unless is_nil(building) do
        {_, _} = building |> Building.update_building(attrs)
        IO.puts("ALREADY PRESENT: Building #{name} updated")
      end
    end
  end

  def fetch_location(coordinates) do
    coordinates = coordinates |> String.split(",")

    coordinates = {String.to_float(Enum.at(coordinates, 0) |> ApplicationHelper.strip_chars(", ")), String.to_float(Enum.at(coordinates, 1) |> ApplicationHelper.strip_chars(", "))}

    %Geo.Point{coordinates: coordinates, srid: 4326}
  end
end
