defmodule BnApis.Places.Zone do
  use Ecto.Schema
  alias BnApis.Repo
  import Ecto.Changeset
  alias BnApis.Places.{City, Zone, Polygon}
  alias BnApis.Orders.MatchPlusPackage
  import Ecto.Query

  schema "zones" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :name, :string
    field :is_active, :boolean, default: true

    belongs_to :city, City
    belongs_to :match_plus_package, MatchPlusPackage
    has_many :polygons, Polygon

    timestamps()
  end

  @fields [:id, :uuid, :name, :is_active, :city_id, :match_plus_package_id]
  @required_fields [:name, :city_id]

  @doc false
  def changeset(zone, attrs) do
    zone
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
  end

  def create(attrs \\ %{}) do
    case %Zone{}
         |> Zone.changeset(attrs)
         |> Repo.insert() do
      {:ok, zone} -> {:ok, zone |> Repo.preload([:city, :polygons, :match_plus_package])}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def fetch_from_uuid(uuid) do
    zone = Repo.get_by(Zone, uuid: uuid, is_active: true) |> Repo.preload([:city, :polygons, :match_plus_package])

    if is_nil(zone) do
      {:error, :not_found}
    else
      {:ok, zone}
    end
  end

  def all_zones(params) do
    case params do
      %{"city_id" => val} ->
        Repo.all(from(z in Zone, where: z.city_id == ^val and z.is_active == true, select: z, preload: [:city, :polygons, :match_plus_package]))

      %{} ->
        Repo.all(from z in Zone, where: z.is_active == true, preload: [:city, :polygons, :match_plus_package])
    end
  end

  def update_zone(params) do
    case params do
      %{
        "uuid" => uuid,
        "name" => name,
        "city_id" => city_id,
        "match_plus_package_id" => match_plus_package_id
      } ->
        case Repo.get_by(Zone, uuid: uuid, is_active: true) do
          nil ->
            {:error, "Zone not found"}

          zone ->
            Repo.transaction(fn ->
              try do
                params = %{
                  "name" => if(is_nil(name), do: zone.name, else: name),
                  "city_id" => if(is_nil(city_id), do: zone.city_id, else: city_id),
                  "match_plus_package_id" => if(is_nil(match_plus_package_id), do: zone.match_plus_package_id, else: match_plus_package_id)
                }

                zone
                |> changeset(params)
                |> Repo.update!()
                |> Repo.preload([:city, :polygons, :match_plus_package])
              rescue
                err ->
                  Repo.rollback(Exception.message(err))
              end
            end)
        end

      _ ->
        {:error, "Invalid params"}
    end
  end

  def get_zone_by(params, preload \\ []) do
    query = fetch_zones_by(params, preload)
    query |> Repo.one()
  end

  defp fetch_zones_by(params, preload) do
    where = Map.to_list(params)

    Zone
    |> where([z], ^where)
    |> preload(^preload)
  end
end
