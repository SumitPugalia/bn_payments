defmodule Mix.Tasks.UpdateMatchParametersInPolygon do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Places.Polygon

  @shortdoc "update match_parameters in polygon"
  def run(_) do
    Mix.Task.run("app.start", [])

    Polygon
    |> Repo.all()
    |> Enum.map(&update_polygon_data/1)
  end

  def update_polygon_data(polygon) do
    {rent_match_parameters, resale_match_parameters} = {polygon.rent_match_parameters, polygon.resale_match_parameters}
    rent_match_parameters = get_updated_rent_match_parameters(rent_match_parameters)
    resale_match_parameters = get_updated_resale_match_parameters(resale_match_parameters)

    update_attrs = %{
      rent_match_parameters: rent_match_parameters,
      resale_match_parameters: resale_match_parameters
    }

    polygon
    |> Polygon.changeset(update_attrs)
    |> Repo.update()

    IO.puts("Polygon #{polygon.name} updated!!")
  end

  def get_updated_rent_match_parameters(rent_match_parameters) do
    rent_match_parameters
    |> Map.merge(%{
      "rent_expected" =>
        rent_match_parameters["rent_expected"]
        |> Map.merge(%{
          "filter" => true,
          "max" => 0.2
        }),
      "configuration_type_id" =>
        rent_match_parameters["configuration_type_id"]
        |> Map.merge(%{
          "filter" => true
        })
    })
  end

  def get_updated_resale_match_parameters(resale_match_parameters) do
    resale_match_parameters
    |> Map.merge(%{
      "price" =>
        resale_match_parameters["price"]
        |> Map.merge(%{
          "filter" => true,
          "max" => 0.2
        }),
      "configuration_type_id" =>
        resale_match_parameters["configuration_type_id"]
        |> Map.merge(%{
          "filter" => true
        })
    })
  end
end
