defmodule Mix.Tasks.UpdateExpiryInPolygon do
  use Mix.Task
  # import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Places.Polygon
  alias BnApis.Posts.{PostType, ConfigurationType}

  @shortdoc "update expiry in polygon"
  def run(_) do
    Mix.Task.run("app.start", [])

    Polygon
    |> Repo.all()
    |> Enum.map(&update_polygon_data/1)
  end

  def update_polygon_data(polygon) do
    expiry_times = expiry_times()

    update_attrs = %{
      resale_config_expiry: polygon.resale_config_expiry |> put_in(["client"], expiry_times[PostType.resale().name]["client"])
    }

    polygon
    |> Polygon.changeset(update_attrs)
    |> Repo.update()

    IO.puts("Polygon #{polygon.name} updated!!")
  end

  def expiry_times() do
    %{
      PostType.rent().name => %{
        "client" => %{
          ConfigurationType.studio().name => 15,
          ConfigurationType.bhk_1().name => 15,
          ConfigurationType.bhk_1_5().name => 15,
          ConfigurationType.bhk_2().name => 15,
          ConfigurationType.bhk_2_5().name => 15,
          ConfigurationType.bhk_3().name => 15,
          ConfigurationType.bhk_3_5().name => 15,
          ConfigurationType.bhk_4().name => 15,
          ConfigurationType.bhk_4_plus().name => 15
        },
        "property" => %{
          ConfigurationType.studio().name => 7,
          ConfigurationType.bhk_1().name => 7,
          ConfigurationType.bhk_1_5().name => 7,
          ConfigurationType.bhk_2().name => 7,
          ConfigurationType.bhk_2_5().name => 10,
          ConfigurationType.bhk_3().name => 10,
          ConfigurationType.bhk_3_5().name => 15,
          ConfigurationType.bhk_4().name => 15,
          ConfigurationType.bhk_4_plus().name => 15
        }
      },
      PostType.resale().name => %{
        "client" => %{
          ConfigurationType.studio().name => 15,
          ConfigurationType.bhk_1().name => 15,
          ConfigurationType.bhk_1_5().name => 15,
          ConfigurationType.bhk_2().name => 15,
          ConfigurationType.bhk_2_5().name => 15,
          ConfigurationType.bhk_3().name => 15,
          ConfigurationType.bhk_3_5().name => 15,
          ConfigurationType.bhk_4().name => 15,
          ConfigurationType.bhk_4_plus().name => 15
        },
        "property" => %{
          ConfigurationType.studio().name => 30,
          ConfigurationType.bhk_1().name => 30,
          ConfigurationType.bhk_1_5().name => 30,
          ConfigurationType.bhk_2().name => 30,
          ConfigurationType.bhk_2_5().name => 30,
          ConfigurationType.bhk_3().name => 45,
          ConfigurationType.bhk_3_5().name => 45,
          ConfigurationType.bhk_4().name => 45,
          ConfigurationType.bhk_4_plus().name => 45
        }
      }
    }
  end
end
