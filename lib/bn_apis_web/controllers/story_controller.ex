defmodule BnApisWeb.StoryController do
  use BnApisWeb, :controller

  alias BnApis.{Stories, Posts}
  alias BnApis.Rewards.StoryTransaction
  alias BnApis.Stories.StoryProjectConfig
  alias BnApisWeb.Helpers.StoryHelper
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Helpers.{Connection, Time, Utils}
  alias BnApis.Rewards.StoryTierPlanMapping

  action_fallback(BnApisWeb.FallbackController)

  plug(
    :access_check,
    [
      allowed_roles: [
        EmployeeRole.super().id,
        EmployeeRole.story_admin().id,
        EmployeeRole.admin().id,
        EmployeeRole.broker_admin().id,
        EmployeeRole.bd_team().id
      ]
    ]
    when action in [:index]
  )

  plug(
    :access_check,
    [allowed_roles: [EmployeeRole.super().id, EmployeeRole.story_admin().id, EmployeeRole.admin().id]]
    when action in [:create, :update, :broadcast, :create_story_tier]
  )

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] do
      conn
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end

  def meta(conn, _params) do
    response = %{
      resource_types: BnApis.Stories.SectionResourceType.seed_data(),
      attachment_types: BnApis.Stories.AttachmentType.seed_data(),
      story_tiers: BnApis.Rewards.StoryTier.get_data(),
      gst_code_to_place_of_supply: BnApis.Stories.LegalEntity.get_gst_code_to_place_of_supply_map(),
      templates: [
        "broadcast",
        "broadcast_v1"
      ]
    }

    conn |> put_status(200) |> json(response)
  end

  def get_template(conn, %{
        "story_uuid" => story_uuid,
        "template_name" => template_name
      }) do
    user_id = conn.assigns[:user]["user_id"]
    story_data = StoryHelper.fetch_story_data(story_uuid, user_id)

    background_url =
      (story_data[:data][:sections]
       |> Enum.filter(&(&1.order == 1))
       |> List.first())[:resource_url]

    {:safe, html} =
      Phoenix.View.render(BnApisWeb.StoryView, "#{template_name}.html",
        story_data: story_data[:data],
        background_url: background_url
      )

    send_resp(conn, :ok, html)
  end

  def index(conn, params) do
    user_id = conn.assigns[:user]["user_id"]
    stories = Stories.list_stories(params)
    render(conn, "admin_index.json", stories: stories, user_id: user_id)
  end

  def create(conn, %{"story" => story_params}) do
    story_params = story_params |> create_params()
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _story} <- Stories.create_story(story_params, user_map) do
      send_resp(conn, :ok, "Successfully Inserted!")
    end
  end

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

  def fetch_story(conn, %{"story_uuid" => uuid}) do
    is_admin_call = true
    user_id = conn.assigns[:user]["user_id"]
    story = Stories.get_story_from_uuid!(uuid, is_admin_call)
    render(conn, "show_admin.json", story: story, user_id: user_id)
  end

  def update(conn, %{"story_uuid" => uuid, "story" => story_params}) do
    is_admin_call = true
    user_id = conn.assigns[:user]["user_id"]
    story = Stories.get_story_from_uuid!(uuid, is_admin_call)
    story_params = story_params |> update_params()
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, story} <- Stories.update_story(story, story_params, user_map) do
      render(conn, "show_admin.json", story: story, user_id: user_id)
    else
      {:error, error_message} -> conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(error_message)})
    end
  end

  def delete(conn, %{"story_uuid" => uuid}) do
    is_admin_call = true
    story = Stories.get_story_from_uuid!(uuid, is_admin_call)
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _} <- Stories.delete_story(story, user_map) do
      send_resp(conn, :no_content, "")
    end
  end

  def dashboard(conn, params) do
    user_data = %{
      user_id: conn.assigns[:user]["user_id"],
      organization_id: conn.assigns[:user]["profile"]["organization_id"],
      operating_city: conn.assigns[:user]["profile"]["operating_city"]
    }

    page = (params["p"] && params["p"] |> String.to_integer()) || 1

    {stories, has_more_stories, _total_count} = Stories.fetch_all_stories(page, user_data[:operating_city])

    {:ok, outstanding_matches, _has_more_om_posts, _outstanding_matches_count} = Posts.all_outstanding_matches(user_data[:user_id], page)

    # max_outstanding_pages = outstanding_matches_count/Posts.post_per_page()

    {:ok, expiring_posts, _has_more_expiring_posts} =
      Posts.fetch_all_expiring_posts(
        user_data[:organization_id],
        user_data[:user_id],
        page
      )

    # {:ok, already_contacted_matches, _has_more_acm_posts} = Posts.all_already_contacted_matches(user_data[:user_id], page)
    # {:ok, read_matches, _has_more_read_posts} = if page <= max_outstanding_pages do
    #   # we have outstanding  matches to fill so don't show read
    #   {:ok, [], true}
    # else
    #   read_page = (page - max_outstanding_pages) |> Float.ceil() |> trunc()
    #   Posts.all_read_matches(user_data[:user_id], read_page)
    # end

    render(conn, "dashboard.json",
      stories: stories,
      has_more_stories: has_more_stories,
      outstanding_matches: outstanding_matches,
      posts_expiring: expiring_posts,
      user_data: user_data,
      page: page,
      has_more: true,
      show_team_member_card: StoryHelper.show_team_member_card(user_data[:organization_id])
    )
  end

  def mark_seen(conn, %{
        "story_uuid" => story_uuid,
        "section_uuid" => section_uuid,
        "timestamp" => timestamp
      }) do
    user_uuid = conn.assigns[:user]["uuid"]

    with {:ok, _user_seen} <-
           Stories.mark_seen(user_uuid, story_uuid, section_uuid, timestamp) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked as seen!"})
    end
  end

  def mark_favourite(conn, %{
        "story_uuid" => story_uuid,
        "timestamp" => timestamp
      }) do
    user_uuid = conn.assigns[:user]["uuid"]

    with {:ok, _story} <-
           Stories.mark_favourite(user_uuid, story_uuid, timestamp) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked as favourite!"})
    end
  end

  def update_story_transaction(conn, params) do
    is_admin_call = true
    {story_uuid, amount} = {params["story_uuid"], params["amount"]}
    user_id = conn.assigns[:user]["user_id"]
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    story = Stories.get_story_from_uuid!(story_uuid, is_admin_call)
    legal_entity_id = Map.get(params, "legal_entity_id")

    # if story.is_rewards_enabled == true do
    with {:ok, _story_transaction} <-
           StoryTransaction.create_story_transaction!(amount, user_id, story.id, params["remark"], params["proof_url"], legal_entity_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Topup amount entered Successfully"})
    else
      {:error, _message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Topup amount could not be entered Successfully"})
    end

    # else
    #   conn
    #     |> put_status(:bad_request)
    #     |> json(%{message: "Rewards are not enabled for this story"})
    # end
  end

  def get_story_transaction(conn, params) do
    is_admin_call = true
    story = Stories.get_story_from_uuid!(params["story_uuid"], is_admin_call)
    transactions = StoryTransaction.get_story_transactions(story.id)

    conn
    |> put_status(:ok)
    |> json(%{response: transactions})
  end

  def create_story_tier(conn, params) do
    user_id = conn.assigns[:user]["user_id"]

    with {status, response} <-
           Stories.create_story_tier(params["amount"], params["name"], params["is_default"], user_id) do
      conn
      |> put_status(status)
      |> json(%{data: response})
    end
  end

  def remove_favourite(conn, %{"story_uuid" => story_uuid}) do
    user_uuid = conn.assigns[:user]["uuid"]

    with {:ok, _story} <- Stories.remove_favourite(user_uuid, story_uuid) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully removed as favourite!"})
    end
  end

  @doc """
  Paginated. No archived stories in this.
  """
  def fetch_all_stories(conn, params) do
    user_id = conn.assigns[:user]["user_id"]
    filters = params |> StoryHelper.process_filter_params()

    {stories, has_more_stories, _total_count} =
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

        sales_kits =
          story.story_sales_kits
          |> Enum.map(fn attachment ->
            size_in_mb =
              if is_nil(attachment.size_in_mb),
                do: attachment.size_in_mb,
                else: attachment.size_in_mb |> Decimal.to_float()

            %{
              uuid: attachment.uuid,
              name: attachment.name,
              thumbnail: attachment.thumbnail,
              share_url: attachment.share_url,
              preview_url: attachment.preview_url,
              size_in_mb: size_in_mb,
              type: attachment.attachment_type_id,
              attachment_type_id: attachment.attachment_type_id,
              active: attachment.active
            }
          end)

        project_configs =
          story.story_project_configs
          |> Enum.map(fn project_config ->
            %{
              uuid: project_config.uuid,
              carpet_area: project_config.carpet_area,
              starting_price: project_config.starting_price,
              configuration_type_id: project_config.configuration_type_id,
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
        # balances = BnApis.Stories.Story.get_story_balances(story)

        %{
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
          is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced",
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
          gate_pass: Utils.parse_url(story.gate_pass),
          on_priority: length(story.priority_stories) > 0
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{
      has_more_stories: has_more_stories,
      stories: stories
    })

    # render(conn, "all_stories.json",
    #   stories: stories,
    #   has_more_stories: has_more_stories,
    #   user_id: user_id
    # )
  end

  @doc """
  Paginated. Sends archived stories as well.
  """
  def fetch_all_favourite_stories(conn, params) do
    user_id = conn.assigns[:user]["user_id"]
    page = (params["p"] && params["p"] |> String.to_integer()) || 1

    {stories, has_more_stories} = Stories.fetch_all_favourite_stories(user_id, page)

    render(conn, "all_stories.json",
      stories: stories,
      has_more_stories: has_more_stories,
      user_id: user_id
    )
  end

  def broadcast(conn, params) do
    user_id = conn.assigns[:user]["user_id"]

    {story_uuid, user_uuids, template_name, app_version, notif_type} =
      {params["story_uuid"], params["user_uuids"], params["template_name"], params["app_version"] || "102029", params["notif_type"] || "NEW_STORY_ALERT"}

    Exq.enqueue(Exq, "story", BnApis.StoryBroadcastWorker, [
      user_id,
      story_uuid,
      user_uuids,
      template_name,
      app_version,
      notif_type
    ])

    conn |> put_status(:ok) |> json(%{message: "Success!"})
  end

  def search(conn, params) do
    {user_id, operating_city} = {conn.assigns[:user]["user_id"], conn.assigns[:user]["profile"]["operating_city"]}

    parse_youtube_urls = false

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

  def legal_entity_search(conn, params) do
    operating_city_id = conn.assigns[:user]["profile"]["operating_city"]
    suggestions = Stories.get_story_legal_entity_suggestions(params, operating_city_id)

    conn
    |> put_status(:ok)
    |> json(suggestions)
  end

  def admin_search(conn, params) do
    search_text = params["q"]
    cityId = params["city_id"]
    is_cab_booking_enabled = params["is_cab_booking_enabled"]
    search_text = if not is_nil(search_text), do: search_text |> String.downcase(), else: search_text
    suggestions = Stories.get_admin_story_suggestions(search_text, [], cityId, is_cab_booking_enabled)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def filter(conn, params) do
    {user_id, operating_city} = {conn.assigns[:user]["user_id"], conn.assigns[:user]["profile"]["operating_city"]}

    exclude_story_uuids =
      if params["exclude_story_uuids"] == "" or
           is_nil(params["exclude_story_uuids"]),
         do: [],
         else: params["exclude_story_uuids"] |> String.split(",")

    filters = params |> StoryHelper.process_filter_params()

    suggestions =
      Stories.filter_story_suggestions(
        filters,
        user_id,
        operating_city,
        exclude_story_uuids
      )

    conn
    |> put_status(:ok)
    |> json(%{stories: suggestions})
  end

  def filter_count(conn, params) do
    {user_id, operating_city} = {conn.assigns[:user]["user_id"], conn.assigns[:user]["profile"]["operating_city"]}

    exclude_story_uuids =
      if params["exclude_story_uuids"] == "" or
           is_nil(params["exclude_story_uuids"]),
         do: [],
         else: params["exclude_story_uuids"] |> String.split(",")

    filters = params |> StoryHelper.process_filter_params()

    suggestions_count =
      Stories.filter_story_suggestions_count(
        filters,
        user_id,
        operating_city,
        exclude_story_uuids
      )

    conn
    |> put_status(:ok)
    |> json(%{count: suggestions_count})
  end

  def create_call_log(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    params = params |> create_call_log_params(logged_in_user)
    {:ok, call_log} = params |> Stories.create_story_call_log()
    conn |> put_status(:ok) |> json(%{uuid: call_log.uuid})
  end

  def update_call_log(conn, params) do
    params = params |> update_call_log_params()

    story_call_log = Stories.get_story_call_log_from_uuid!(params["story_call_log_uuid"])

    {:ok, call_log} = story_call_log |> Stories.update_story_call_log(params)
    conn |> put_status(:ok) |> json(%{uuid: call_log.uuid})
  end

  @doc """
    #1. generate pdf from html of the logged in user
    #2. fetch sales kit document from s3
    #3. append above pdf in step 1 at the end of doc fetched in step 2
    #4. upload to s3 and return that s3 url
  """
  def sales_kit_document(conn, %{"sales_kit_uuid" => sales_kit_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    Exq.enqueue(
      Exq,
      "personalised_sales_kit_generator",
      BnApis.PersonalisedDataWorker,
      [logged_in_user, sales_kit_uuid]
    )

    conn |> put_status(:ok) |> json(%{message: "Success", data: %{url: ""}})
  end

  def fetch_rewards_enables_stories(conn, _params) do
    stories = Stories.fetch_rewards_enables_stories(conn.assigns[:user]["profile"]["operating_city"])

    conn |> put_status(:ok) |> json(%{"stories" => stories})
  end

  defp create_params(params) do
    params
    |> Map.merge(%{
      "developer_id" =>
        (params["developer_uuid"]
         |> BnApis.Developers.get_developer_by_uuid!()).id,
      "configuration_type_ids" => params["configuration_type_ids"] |> configuration_type_ids_params(),
      "possession_by" => params["possession_by"] && Time.epoch_to_naive(params["possession_by"])
    })
  end

  defp update_params(params) do
    story_sections =
      params["story_sections"]
      |> Enum.map(fn section ->
        if section["uuid"],
          do:
            put_in(
              section,
              ["id"],
              Stories.get_story_section_by_uuid!(section["uuid"]).id
            ),
          else: section
      end)

    story_sales_kits =
      params["story_sales_kits"]
      |> Enum.map(fn sales_kit ->
        if sales_kit["uuid"],
          do:
            put_in(
              sales_kit,
              ["id"],
              Stories.get_story_sales_kit_by_uuid!(sales_kit["uuid"]).id
            ),
          else: sales_kit
      end)

    story_project_configs =
      params["story_project_configs"]
      |> Enum.map(fn project_config ->
        if project_config["uuid"],
          do:
            put_in(
              project_config,
              ["id"],
              StoryProjectConfig.get_by_uuid!(project_config["uuid"]).id
            ),
          else: project_config
      end)

    params =
      case params do
        %{"polygon" => nil} ->
          Map.put(params, "polygon_id", nil)

        %{"polygon" => polygon} ->
          Map.put(params, "polygon_id", polygon["id"])

        _ ->
          params
      end

    params =
      case params do
        %{"rewards_bn_poc" => nil} ->
          Map.put(params, "rewards_bn_poc_id", nil)

        %{"rewards_bn_poc" => rewards_bn_poc} ->
          Map.put(params, "rewards_bn_poc_id", rewards_bn_poc["id"])

        _ ->
          params
      end

    params =
      case params do
        %{"sv_business_development_manager" => nil} ->
          Map.put(params, "sv_business_development_manager_id", nil)

        %{"sv_business_development_manager" => sv_business_development_manager} ->
          Map.put(params, "sv_business_development_manager_id", sv_business_development_manager["id"])

        _ ->
          params
      end

    params =
      case params do
        %{"sv_implementation_manager" => nil} ->
          Map.put(params, "sv_implementation_manager_id", nil)

        %{"sv_implementation_manager" => sv_implementation_manager} ->
          Map.put(params, "sv_implementation_manager_id", sv_implementation_manager["id"])

        _ ->
          params
      end

    params =
      case params do
        %{"sv_market_head" => nil} -> Map.put(params, "sv_market_head_id", nil)
        %{"sv_market_head" => sv_market_head} -> Map.put(params, "sv_market_head_id", sv_market_head["id"])
        _ -> params
      end

    params =
      case params do
        %{"sv_cluster_head" => nil} -> Map.put(params, "sv_cluster_head_id", nil)
        %{"sv_cluster_head" => sv_cluster_head} -> Map.put(params, "sv_cluster_head_id", sv_cluster_head["id"])
        _ -> params
      end

    params =
      case params do
        %{"sv_account_manager" => nil} ->
          Map.put(params, "sv_account_manager_id", nil)

        %{"sv_account_manager" => sv_account_manager} ->
          Map.put(params, "sv_account_manager_id", sv_account_manager["id"])

        _ ->
          params
      end

    params =
      case params do
        %{"developer_pocs" => nil} ->
          Map.put(params, "developer_poc_ids", [])

        %{"developer_pocs" => developer_pocs} ->
          Map.put(
            params,
            "developer_poc_ids",
            Enum.map(developer_pocs, &Map.get(&1, "id"))
          )

        _ ->
          params
      end

    params
    |> Map.merge(%{
      "story_sections" => story_sections,
      "story_sales_kits" => story_sales_kits,
      "story_project_configs" => story_project_configs,
      "developer_id" =>
        (params["developer_uuid"]
         |> BnApis.Developers.get_developer_by_uuid!()).id,
      "configuration_type_ids" => params["configuration_type_ids"] |> configuration_type_ids_params(),
      "possession_by" => params["possession_by"] && Time.epoch_to_naive(params["possession_by"])
    })
  end

  defp configuration_type_ids_params(configuration_type_ids) do
    case configuration_type_ids do
      "" -> []
      nil -> []
      _ -> configuration_type_ids
    end
  end

  defp create_call_log_params(params, logged_in_user) do
    params
    |> Map.merge(%{
      "phone_number" => logged_in_user[:phone_number] || "9711227605",
      "country_code" => logged_in_user[:country_code] || "+91",
      "start_time" =>
        if(is_nil(params["start_time"]),
          do: params["start_time"],
          else: params["start_time"] |> Time.epoch_to_naive()
        ),
      "story_id" =>
        params["story_uuid"]
        |> Stories.get_story_from_uuid!()
        |> Map.fetch!(:id)
    })
  end

  defp update_call_log_params(params) do
    params
    |> Map.merge(%{
      "end_time" =>
        if(is_nil(params["end_time"]),
          do: params["end_time"],
          else: params["end_time"] |> Time.epoch_to_naive()
        )
    })
  end

  def add_story_tier_plan(conn, params) do
    with {:ok, data} <- StoryTierPlanMapping.create_story_tier_mapping(params) do
      response_data = %{
        story_tier_plan_mapping_id: data.id,
        start_date: data.start_date |> Time.naive_to_epoch_in_sec(),
        end_date: data.end_date |> Time.naive_to_epoch_in_sec(),
        story_id: data.story_id,
        story_tier_id: data.story_tier_id
      }

      conn
      |> put_status(:ok)
      |> json(%{message: "Mapping added for the story tier", data: response_data})
    end
  end

  def update_story_tier_plan(conn, params) do
    with {:ok, data} <-
           StoryTierPlanMapping.update_story_tier_plan(params) do
      response_data = %{
        story_tier_plan_mapping_id: data.id,
        start_date: data.start_date |> Time.naive_to_epoch_in_sec(),
        end_date: data.end_date |> Time.naive_to_epoch_in_sec(),
        story_id: data.story_id,
        story_tier_id: data.story_tier_id
      }

      conn
      |> put_status(:ok)
      |> json(%{message: "Mapping updated succesfully", data: response_data})
    end
  end
end
