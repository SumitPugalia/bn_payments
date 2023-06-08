defmodule Mix.Tasks.UpdateCityIdToCabs do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Cabs.Driver
  alias BnApis.Cabs.Vehicle
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Cabs.BookingSlot

  def run(_) do
    Mix.Task.run("app.start", [])
    update_city()
  end

  defp update_city() do
    Driver
    |> Repo.all()
    |> Enum.each(fn driver ->
      driver |> Driver.changeset(%{"city_id" => 1}) |> Repo.update!()
    end)

    Vehicle
    |> Repo.all()
    |> Enum.each(fn driver ->
      driver |> Vehicle.changeset(%{"city_id" => 1}) |> Repo.update!()
    end)

    BookingRequest
    |> Repo.all()
    |> Enum.each(fn driver ->
      driver |> BookingRequest.changeset(%{"city_id" => 1}) |> Repo.update!()
    end)

    BookingSlot
    |> Repo.all()
    |> Enum.each(fn driver ->
      driver |> BookingSlot.changeset(%{"city_id" => 1}) |> Repo.update!()
    end)
  end
end
