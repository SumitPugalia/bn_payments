defmodule Mix.Tasks.PopulatePolygonInBuilding do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Buildings.Building

  @shortdoc "populates polygon in building"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    File.stream!("#{File.cwd!()}/priv/data/building_polygons.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&populate_building_with_polygon/1)
  end

  def populate_building_with_polygon({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def populate_building_with_polygon({:ok, data}) do
    # note - this one timer might also be modified to create polygons data initially
    building_id = data |> Enum.at(0)
    polygon_name = data |> Enum.at(1)

    attrs = %{
      "polygon_id" => BnApis.Places.Polygon.fetch_or_create_polygon(polygon_name).id
    }

    building = Repo.get(Building, building_id)

    unless is_nil(building) do
      {_, _} = building |> Building.update_building(attrs)
      IO.puts("ALREADY PRESENT: Building id: #{building_id} updated")
    end
  end
end
