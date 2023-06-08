defmodule BnApisWeb.V1.StoryController do
  use BnApisWeb, :controller

  alias BnApis.Stories
  alias BnApis.Stories.Story
  alias BnApisWeb.Helpers.StoryHelper
  alias BnApis.Stories.StoryLegalEntityMapping
  alias BnApis.Helpers.{Time, Connection}
  alias BnApis.Helpers.Utils
  alias BnApis.Places.City

  action_fallback(BnApisWeb.FallbackController)

  def show(conn, %{"story_uuid" => uuid}) do
    user_id = conn.assigns[:user]["user_id"]
    story = Stories.get_story_from_uuid!(uuid)

    if is_nil(story) do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Story does not exist."})
    else
      conn
      |> put_status(:ok)
      |> render(BnApisWeb.StoryView, "show_api_new.json", story: story, user_id: user_id)
    end
  end

  @doc """
  Paginated. No archived stories in this.
  """
  def fetch_all_stories(conn, params) do
    user_id = conn.assigns[:user]["user_id"]
    filters = params |> StoryHelper.process_filter_params()

    {stories, has_more_stories, total_count} =
      Stories.fetch_all_stories(
        filters["page"],
        conn.assigns[:user]["profile"]["operating_city"],
        filters
      )

    stories =
      stories
      |> Enum.map(fn story ->
        user_favourite =
          story.user_favourites
          |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
          |> List.first()

        sections =
          story.story_sections
          |> Enum.map(fn section ->
            %{
              uuid: section.uuid,
              interval: section.interval,
              type: section.resource_type_id,
              order: section.order,
              resource_type_id: section.resource_type_id,
              resource_url: section.resource_url,
              seen: false,
              active: section.active
            }
          end)

        sales_kits = Stories.create_map_for_story_sales_kits(story.story_sales_kits)

        project_configs =
          story.story_project_configs
          |> Enum.map(fn project_config ->
            configuration_type =
              case project_config.configuration_type do
                nil ->
                  nil

                configuration_type ->
                  %{
                    id: configuration_type.id,
                    name: configuration_type.name
                  }
              end

            %{
              uuid: project_config.uuid,
              carpet_area: project_config.carpet_area,
              starting_price: project_config.starting_price,
              configuration_type_id: project_config.configuration_type_id,
              configuration_type: configuration_type,
              active: project_config.active
            }
          end)

        developer_pocs = BnApis.Stories.Story.get_developer_pocs(story)

        developer_pocs_response =
          developer_pocs
          |> Enum.map(fn developer_poc ->
            %{
              id: developer_poc.id,
              uuid: developer_poc.uuid,
              name: developer_poc.name,
              phone_number: developer_poc.phone_number,
              last_active_at: developer_poc.last_active_at,
              active: developer_poc.active
            }
          end)

        locality =
          case story.polygon do
            %{name: name} ->
              name

            _ ->
              ""
          end

        polygon =
          case story.polygon do
            nil ->
              nil

            polygon ->
              %{
                id: polygon.id,
                uuid: polygon.uuid,
                name: polygon.name,
                city_id: polygon.city_id
              }
          end

        project_type_id = story.project_type_id

        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
        operating_city = City.get_city_by_id(conn.assigns[:user]["profile"]["operating_city"])

        %{
          id: story.id,
          title: story.developer.name,
          developer_name: story.developer.name,
          developer_uuid: story.developer.uuid,
          sub_title: story.name,
          name: story.name,
          contact_number: story.phone_number,
          phone_number: story.phone_number,
          thumbnail: story.image_url,
          developer_logo: story.developer.logo_url,
          uuid: story.uuid,
          interval: story.interval,
          timestamp: story.inserted_at |> Time.naive_to_epoch(),
          favourite: not is_nil(user_favourite) || false,
          archived: story.archived,
          seen:
            sections
            |> Enum.map(fn section -> section[:seen] end)
            |> Enum.reduce(true, fn i, flag -> flag && i end),
          sections: sections |> Enum.sort_by(& &1[:order]),
          sales_kits: sales_kits,
          project_configs: project_configs,
          published: story.published,
          contact_person_name: story.contact_person_name,
          operating_cities: story.operating_cities,
          max_carpet_area: story.max_carpet_area,
          min_carpet_area: story.min_carpet_area,
          possession_by: story.possession_by |> Time.naive_to_epoch(),
          configuration_type_ids: story.configuration_type_ids,
          thumbnail_image_url: story.thumbnail_image_url,
          new_story_thumbnail_image_url: story.new_story_thumbnail_image_url,
          project_logo_url: story.project_logo_url,
          is_rewards_enabled: story.is_rewards_enabled,
          is_manually_deacticated_for_rewards: story.is_manually_deacticated_for_rewards,
          is_cab_booking_enabled: story.is_cab_booking_enabled,
          is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced" && operating_city.feature_flags["invoice"] == true,
          is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular" && operating_city.feature_flags["invoice"] == true,
          is_invoicing_enabled: story.is_invoicing_enabled,
          is_enabled_for_commercial: story.is_enabled_for_commercial,
          invoicing_type: story.invoicing_type,
          brokerage_proof_url: story.brokerage_proof_url,
          advanced_brokerage_percent: story.advanced_brokerage_percent,
          rera_ids: story.rera_ids,
          total_credits_amount: 0,
          total_debits_amount: 0,
          total_pending_or_approved_amount: 0,
          latitude: story.latitude,
          longitude: story.longitude,
          google_maps_url: story.google_maps_url,
          project_type_id: project_type_id,
          marketing_kit_url: story.marketing_kit_url,
          developer_pocs: developer_pocs_response,
          locality: locality,
          polygon: polygon,
          story_tier_id: story.story_tier_id,
          on_priority: length(story.priority_stories) > 0,
          gate_pass: Utils.parse_url(story.gate_pass),
          avg_cost_per_sq_ft: Stories.calculate_avg_cost_per_sq_ft(story.story_project_configs),
          is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities) && operating_city.feature_flags["booking_rewards"] == true,
          legal_entities: legal_entities
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{
      total_count: total_count,
      has_more_stories: has_more_stories,
      stories: stories
    })
  end

  @doc """
  Paginated. Sends archived stories as well.
  """
  def fetch_all_favourite_stories(conn, params) do
    user_id = conn.assigns[:user]["user_id"]
    page = Map.get(params, "p", "1") |> String.to_integer()

    {stories, has_more_stories} = Stories.fetch_all_favourite_stories(user_id, page)

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.StoryView, "all_stories_new.json",
      stories: stories,
      has_more_stories: has_more_stories,
      user_id: user_id
    )
  end

  def search(conn, params) do
    {user_id, operating_city} = {conn.assigns[:user]["user_id"], conn.assigns[:user]["profile"]["operating_city"]}

    parse_youtube_urls = true

    suggestions =
      Stories.get_story_suggestions(
        user_id,
        operating_city,
        params,
        parse_youtube_urls
      )

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def filters_metadata(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    data = Stories.get_project_filters_metadata(logged_in_user)

    conn
    |> put_status(:ok)
    |> json(%{data: data})
  end
end
