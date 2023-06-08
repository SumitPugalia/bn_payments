defmodule BnApisWeb.V1.ZoneView do
  use BnApisWeb, :view
  alias BnApisWeb.V1.ZoneView
  alias BnApis.Orders.MatchPlusPackage
  alias BnApis.Repo

  def render("index.json", %{zones: zones}) do
    %{data: render_many(zones, ZoneView, "zone.json")}
  end

  def render("show.json", %{zone: zone}) do
    %{data: render_one(zone, ZoneView, "zone.json")}
  end

  def render("show.json", %{zones: zones}) do
    %{data: render_many(zones, ZoneView, "zone.json")}
  end

  def render("zone.json", %{zone: zone}) do
    zone |> Repo.preload(:match_plus_package)

    match_plus_package =
      if not is_nil(zone.match_plus_package_id) do
        MatchPlusPackage.get_match_plus_package_data(zone.match_plus_package)
      else
        %{}
      end

    %{
      id: zone.id,
      uuid: zone.uuid,
      name: zone.name,
      city: %{
        city_id: zone.city.id,
        city_name: zone.city.name
      },
      match_plus_package: match_plus_package
    }
  end
end
