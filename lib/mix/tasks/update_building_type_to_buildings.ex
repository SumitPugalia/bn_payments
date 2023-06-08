defmodule Mix.Tasks.UpdateBuildingTypesToBuildings do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Buildings.Building

  def run(_) do
    Mix.Task.run("app.start", [])
    update_building()
  end

  defp update_building() do
    Building
    |> Repo.all()
    |> Enum.each(fn building ->
      building |> Building.changeset(%{"type" => "residential"}) |> Repo.update!()
    end)
  end
end
