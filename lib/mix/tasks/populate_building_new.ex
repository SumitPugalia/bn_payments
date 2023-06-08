defmodule Mix.Tasks.PopulateBuildingNew do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Buildings.Building
  alias BnApis.Helpers.ApplicationHelper

  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    File.stream!("#{File.cwd!()}/priv/data/buildings.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&create_building_data/1)
  end

  def create_building_data({:ok, data}) do
    city_id = ApplicationHelper.get_city_id_from_name(data |> Enum.at(0))
    polygon_name = data |> Enum.at(1)
    name = data |> Enum.at(2)
    lat = data |> Enum.at(3)
    lon = data |> Enum.at(4)
    building_type = data |> Enum.at(6)
    coordinates = {lat, lon}
    location = %Geo.Point{coordinates: coordinates, srid: 4326}

    attrs = %{
      "name" => name,
      "display_address" => data |> Enum.at(5),
      "type" => if(building_type == "commercial", do: "commercial", else: "residential"),
      "location" => location,
      "polygon_id" => BnApis.Places.Polygon.fetch_or_create_polygon(polygon_name, city_id).id,
      "total_development_size" => data |> Enum.at(7),
      "grade" => data |> Enum.at(8),
      "car_parking_ratio" => data |> Enum.at(9),
      "structure" => data |> Enum.at(10)
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
end
