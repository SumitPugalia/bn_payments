defmodule Mix.Tasks.UpdateCitiesBoundary do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Places.City

  import Ecto.Query

  @file_name ["city_with_boundary.csv"]

  def run(_) do
    Mix.Task.run("app.start", [])
    IO.puts("STARTING TO UPDATE CITY BOUNDARY")

    @file_name
    |> Enum.each(&update_city/1)

    IO.puts("UPDATING CITY BOUNDARY COMPLETED")
  end

  def update_city(file_name) do
    File.stream!("#{File.cwd!()}/priv/data/#{file_name}")
    |> CSV.decode()
    |> Enum.to_list()
    |> Enum.map(&update_city_boundary/1)
  end

  def update_city_boundary({:error, data}) do
    IO.inspect("========== Error: ============")
    IO.inspect(data)
    nil
  end

  def update_city_boundary({:ok, data}) do
    city_name = data |> Enum.at(0)
    country_id = data |> Enum.at(1)
    sw_lat = data |> Enum.at(2)
    sw_lng = data |> Enum.at(3)
    ne_lat = data |> Enum.at(4)
    ne_lng = data |> Enum.at(5)

    formatted_query = "#{String.downcase(String.trim(city_name))}"
    city = City |> where([c], fragment("LOWER(?) = ?", c.name, ^formatted_query)) |> Repo.one()

    IO.puts("City #{city_name} is updated")

    attrs = %{
      "id" => city.id,
      "name" => city_name,
      "country_id" => String.to_integer(country_id),
      "sw_lat" => String.to_float(sw_lat),
      "sw_lng" => String.to_float(sw_lng),
      "ne_lat" => String.to_float(ne_lat),
      "ne_lng" => String.to_float(ne_lng)
    }

    City.changeset(city, attrs) |> Repo.update()
  end
end
