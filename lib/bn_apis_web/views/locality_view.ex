defmodule BnApisWeb.LocalityView do
  use BnApisWeb, :view
  alias BnApisWeb.LocalityView

  def render("index.json", %{localities: localities}) do
    %{data: render_many(localities, LocalityView, "locality.json")}
  end

  def render("show.json", %{locality: locality}) do
    %{data: render_one(locality, LocalityView, "locality.json")}
  end

  def render("locality.json", %{locality: locality}) do
    %{
      # id: locality.id,
      uuid: locality.uuid,
      name: locality.name,
      count: locality.count,
      min_price: locality.min_price,
      max_price: locality.max_price,
      min_rent: locality.min_rent,
      max_rent: locality.max_rent,
      min_area: locality.min_area,
      max_area: locality.max_area
    }
  end
end
