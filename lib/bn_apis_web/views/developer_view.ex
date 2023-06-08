defmodule BnApisWeb.DeveloperView do
  use BnApisWeb, :view
  alias BnApisWeb.DeveloperView
  alias BnApis.Helpers.Time

  def render("index.json", %{developers: developers}) do
    %{data: render_many(developers, DeveloperView, "developer.json")}
  end

  def render("show.json", %{developer: developer}) do
    %{data: render_one(developer, DeveloperView, "developer.json")}
  end

  def render("developer.json", %{developer: developer}) do
    %{
      uuid: developer.uuid,
      name: developer.name,
      email: developer.email,
      logo_url: developer.logo_url,
      micro_market_id: developer.micro_market_id,
      inserted_at: developer.inserted_at |> Time.naive_to_epoch()
    }
  end
end
