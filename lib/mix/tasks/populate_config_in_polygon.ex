defmodule Mix.Tasks.PopulateConfigInPolygon do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Places.Polygon

  @shortdoc "populate config in polygon data"
  def run(_) do
    Mix.Task.run("app.start", [])

    Polygon
    |> Repo.all()
    |> Enum.map(&update_polygon_data/1)
  end

  def update_polygon_data(polygon) do
    update_attrs = %{
      rent_match_parameters: put_in(polygon.rent_match_parameters, [:configuration_type_id], create_configuration_mappings()),
      resale_match_parameters: put_in(polygon.resale_match_parameters, [:configuration_type_id], create_configuration_mappings())
    }

    polygon
    |> Polygon.changeset(update_attrs)
    |> Repo.update()

    IO.puts("Polygon #{polygon.name} updated!!")
  end

  defp create_configuration_mappings() do
    %{
      BnApis.Posts.ConfigurationType.studio().id => ["#{BnApis.Posts.ConfigurationType.studio().id}"],
      BnApis.Posts.ConfigurationType.bhk_1().id => [
        "#{BnApis.Posts.ConfigurationType.studio().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_4_plus().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_4().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_4_plus().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_1_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_1().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_1_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_2_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_2().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_2_5().id}"
      ],
      BnApis.Posts.ConfigurationType.bhk_3_5().id => [
        "#{BnApis.Posts.ConfigurationType.bhk_3().id}",
        "#{BnApis.Posts.ConfigurationType.bhk_3_5().id}"
      ],
      filter: false
    }
  end
end
