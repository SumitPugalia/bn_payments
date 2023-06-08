defmodule BnApisWeb.BuildingView do
  use BnApisWeb, :view
  alias BnApisWeb.BuildingView

  def render("index.json", %{building: building}) do
    %{data: render_one(building, BuildingView, "building.json")}
  end

  def render("show.json", %{building: building}) do
    %{data: render_one(building, BuildingView, "building.json")}
  end

  def render("building.json", %{building: building}) do
    [latitude, longitude] = (building.location |> Geo.JSON.encode!())["coordinates"]

    %{
      id: building.id,
      building_id: building.building_id,
      name: building.name,
      display_address: building.display_address,
      structure: building.structure,
      car_parking_ratio: building.car_parking_ratio,
      total_development_size: building.total_development_size,
      coordinates: [latitude, longitude],
      type_id: building.type_id,
      grade_id: building.grade_id,
      polygon: building.polygon,
      documents: building.documents
    }
  end
end
