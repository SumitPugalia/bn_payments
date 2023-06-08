defmodule Mix.Tasks.PopulateLocalityInPolygon do
  use Mix.Task
  use Ecto.Schema
  alias BnApis.Repo
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Places.{Polygon, Locality}

  @shortdoc "Populate Locality in Polygons"
  def run(_) do
    Mix.Task.run("app.start", [])
    # remove first line from csv file that contains headers

    polygons_query()
    |> Enum.each(&get_locality_and_tag/1)
  end

  def polygons_query() do
    Polygon
    |> select([p], [p.id, p.name])
    |> Repo.all()
  end

  def get_locality_and_tag([pid, polygon_name]) do
    locality_id =
      Locality
      |> where([l], l.name == ^polygon_name)
      |> select([l], l.id)
      |> Repo.all()
      |> List.first()

    unless is_nil(locality_id) do
      Repo.get(Polygon, pid)
      |> change(locality_id: locality_id)
      |> Repo.update()
    end
  end
end
