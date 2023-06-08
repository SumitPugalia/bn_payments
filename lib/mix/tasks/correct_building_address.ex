defmodule Mix.Tasks.CorrectBuildingAddress do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Buildings.Building

  @shortdoc "Correct buildings related data"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers
    File.stream!("#{File.cwd!()}/priv/data/building_address_update.csv")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&update_building_data/1)
  end

  def update_building_data({:error, data}) do
    IO.inspect("Error: #{data}")
    nil
  end

  def update_building_data({:ok, data}) do
    building_uuid = data |> Enum.at(0)

    attrs = %{
      "display_address" => data |> Enum.at(2)
    }

    building = Repo.get_by(Building, uuid: building_uuid)

    unless is_nil(building) do
      {_, _} = building |> Building.update_building(attrs)
      IO.puts("ALREADY PRESENT: Building #{building.name} updated")
    end
  end
end
