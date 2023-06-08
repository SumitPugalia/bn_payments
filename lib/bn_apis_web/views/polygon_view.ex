defmodule BnApisWeb.PolygonView do
  use BnApisWeb, :view
  alias BnApisWeb.PolygonView

  def render("index.json", %{polygons: polygons}) do
    %{data: render_many(polygons, PolygonView, "polygon.json")}
  end

  def render("show.json", %{polygon: polygon}) do
    %{data: render_one(polygon, PolygonView, "polygon.json")}
  end

  def render("polygon.json", %{polygon: polygon}) do
    %{
      id: polygon.id,
      uuid: polygon.uuid,
      name: polygon.name,
      rent_config_expiry: polygon.rent_config_expiry,
      resale_config_expiry: polygon.resale_config_expiry,
      rent_match_parameters: polygon.rent_match_parameters,
      resale_match_parameters: polygon.resale_match_parameters,
      city_id: polygon.city_id,
      zone_id: polygon.zone_id
    }
  end

  def render("polygon_basic.json", %{polygon: polygon}) do
    %{
      id: polygon.id,
      uuid: polygon.uuid,
      name: polygon.name,
      city_id: polygon.city_id,
      zone_id: polygon.zone_id
    }
  end
end
