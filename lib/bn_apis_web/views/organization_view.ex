defmodule BnApisWeb.OrganizationView do
  use BnApisWeb, :view
  alias BnApisWeb.OrganizationView
  alias BnApis.Places.Polygon
  alias BnApis.Organizations.Organization

  def render("index.json", %{organizations: organizations}) do
    %{data: render_many(organizations, OrganizationView, "organization.json")}
  end

  def render("show.json", %{organization: organization}) do
    %{data: render_one(organization, OrganizationView, "organization.json")}
  end

  def render("organization.json", %{organization: organization}) do
    polygon =
      case Organization.get_organization_broker(organization.uuid) do
        nil ->
          nil

        broker ->
          broker.polygon_id |> Polygon.fetch_from_id()
      end

    %{
      id: organization.id,
      name: organization.name,
      uuid: organization.uuid,
      firm_address: organization.firm_address,
      locality_name: polygon && polygon.name,
      locality_uuid: polygon && polygon.uuid
    }
  end
end
