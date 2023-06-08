defmodule BnApisWeb.StoryView do
  use BnApisWeb, :view

  import Ecto.Query
  alias BnApis.Helpers.Time
  alias BnApisWeb.StoryView
  alias BnApisWeb.Helpers.StoryHelper
  alias BnApis.Stories.StoryLegalEntityMapping
  alias BnApis.Repo
  alias BnApis.Stories
  alias BnApis.Stories.Schema.PriorityStory
  alias BnApis.Stories.Story
  alias BnApis.Helpers.Utils
  alias BnApis.Stories.MandateCompanies

  @update_available_card [
    %{
      type: "UPDATE_AVAILABLE",
      data: %{}
    }
  ]

  # @add_team_member_card [
  #   %{
  #     type: "ADD_TEAM_MEMBER",
  #     data: %{}
  #   }
  # ]

  @no_new_matches_card [
    %{
      type: "NO_NEW_MATCHES",
      data: %{}
    }
  ]

  @transaction_data_card [
    %{
      type: "TRANSACTION_DATA",
      data: %{}
    }
  ]

  @static_cards []

  def render("index.json", %{stories: stories, user_id: user_id}) do
    %{data: render_many(stories, StoryView, "story.json", %{user_id: user_id})}
  end

  def render("admin_index.json", %{stories: stories, user_id: user_id}) do
    %{
      data: %{
        stories: render_many(stories.stories, StoryView, "story_admin.json", %{user_id: user_id}),
        has_next_page: stories.has_next_page
      }
    }
  end

  def render("show.json", %{story: story, user_id: user_id}) do
    %{data: render_one(story, StoryView, "story.json", %{user_id: user_id})}
  end

  def render("show_admin.json", %{story: story, user_id: user_id}) do
    %{
      data: render_one(story, StoryView, "story_admin.json", %{user_id: user_id})
    }
  end

  def render("show_api.json", %{story: story, user_id: user_id}) do
    %{
      data: render_one(story, StoryView, "story_api.json", %{user_id: user_id})
    }
  end

  def render("show_api_new.json", %{story: story, user_id: user_id}) do
    %{
      data: render_one(story, StoryView, "story_api_new.json", %{user_id: user_id})
    }
  end

  def render("all_stories.json", %{
        stories: stories,
        has_more_stories: has_more_stories,
        user_id: user_id
      }) do
    %{
      has_more_stories: has_more_stories,
      stories: render_many(stories, StoryView, "story_new.json", %{user_id: user_id})
    }
  end

  def render("all_stories_new.json", %{
        stories: stories,
        has_more_stories: has_more_stories,
        user_id: user_id
      }) do
    %{
      has_more_stories: has_more_stories,
      stories: render_many(stories, StoryView, "story_with_youtube_urls.json", %{user_id: user_id})
    }
  end

  @doc """
  {
    story_card: {
     has_more_stories: <bool>, #indicates more stories are available, pagination of 10
     stories: [story_json, ...]
    },
    calendar_card: {},
  }
  """
  def render("dashboard.json", %{
        stories: stories,
        has_more_stories: has_more_stories,
        outstanding_matches: outstanding_matches,
        posts_expiring: posts_expiring,
        # hot_projects: hot_projects,
        user_data: user_data,
        page: page,
        has_more: has_more,
        show_team_member_card: _show_team_member_card
      }) do
    # builder_connect_card_data = %{
    #   hot_projects: hot_projects
    # }

    posts_expiring_count = posts_expiring |> length()
    matches_cards_data_count = outstanding_matches |> length()

    # Outstanding Matches Bucketing based on broker
    outstanding_matches = outstanding_matches |> StoryHelper.create_outstanding_matches()

    # Expiring Posts
    posts_expiring = posts_expiring |> StoryHelper.create_expiring_posts()

    story_card = %{
      has_more_stories: has_more_stories,
      stories:
        render_many(stories, StoryView, "story.json", %{
          user_id: user_data[:user_id]
        })
    }

    matches_cards =
      if page == 1 && matches_cards_data_count == 0 do
        posts_expiring ++ @no_new_matches_card ++ outstanding_matches
      else
        posts_expiring ++ outstanding_matches
      end

    response = %{
      has_more: has_more,
      cards: matches_cards
    }

    # no need of team member card
    # static_cards = if show_team_member_card, do: @static_cards ++ @add_team_member_card, else: @static_cards
    static_cards = @static_cards

    # add static cards only after all matches cards
    response =
      if posts_expiring_count + matches_cards_data_count == 0 do
        put_in(response, [:cards], response[:cards] ++ static_cards)
      else
        response
      end

    has_more = posts_expiring_count + matches_cards_data_count > 0

    cond do
      page == 1 ->
        # update card only on first page and on top
        response
        |> put_in(
          [:cards],
          @update_available_card ++ @transaction_data_card ++ response[:cards]
        )
        |> Map.merge(%{story_card: story_card, has_more: has_more})

      true ->
        response |> Map.merge(%{has_more: has_more})
    end
  end

  @doc """
  {
    title: <name of developer>,
    thumbnail: <thumb image url>,
    developer_logo: <developer logo url>,
    uuid: <story uuid>,
    interval: <time in seconds to show a slide of story>,
    timestamp: <epoch time, when this story was created>,
    favourite: <boolean>,
    archived: <boolean>,
    seen: <boolean>,
    sections: [
      story_section,
      story_section,
      ...
    ]
  }
  """
  def render("story.json", %{story: story, user_id: user_id}) do
    story =
      story
      |> Repo.preload([
        :user_favourites,
        :story_sections,
        :story_sales_kits,
        :story_project_configs,
        :developer,
        :project_type,
        :polygon,
        :story_developer_poc_mappings,
        story_developer_poc_mappings: [:developer_poc_credential]
      ])

    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits =
      render_many(story.story_sales_kits, StoryView, "story_sales_kit.json", %{
        user_id: user_id
      })

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

    developer_pocs = BnApis.Stories.Story.get_developer_pocs(story)

    developer_pocs_response =
      BnApisWeb.CredentialView.render("developer_pocs_data.json", %{
        data: developer_pocs
      })

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
          render_one(polygon, BnApisWeb.PolygonView, "polygon_basic.json")
      end

    project_type_id = if not is_nil(story.project_type), do: story.project_type.id, else: nil
    # balances = BnApis.Stories.Story.get_story_balances(story)

    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

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
      is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced",
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      story_tier_id: story.story_tier_id,
      avg_cost_per_sq_ft: Stories.calculate_avg_cost_per_sq_ft(story.story_project_configs),
      is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities),
      legal_entities: legal_entities,
      rera_ids: story.rera_ids
    }
  end

  def render("story_new.json", %{story: story, user_id: user_id}) do
    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits =
      render_many(story.story_sales_kits, StoryView, "story_sales_kit_api.json", %{
        user_id: user_id
      })

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

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
      is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced",
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      is_cab_booking_enabled: story.is_cab_booking_enabled,
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
      is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities),
      legal_entities: legal_entities,
      rera_ids: story.rera_ids
    }
  end

  def render("story_with_youtube_urls.json", %{story: story, user_id: user_id}) do
    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits = Stories.create_map_for_story_sales_kits(story.story_sales_kits)

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

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
      id: story.id,
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
      is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced",
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      is_cab_booking_enabled: story.is_cab_booking_enabled,
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
      is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities),
      legal_entities: legal_entities,
      rera_ids: story.rera_ids
    }
  end

  def render("story_mini.json", %{story: story}) do
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

    project_type_id = story.project_type_id

    %{
      title: story.developer.name,
      developer_name: story.developer.name,
      developer_uuid: story.developer.uuid,
      sub_title: story.name,
      name: story.name,
      thumbnail: story.image_url,
      developer_logo: story.developer.logo_url,
      uuid: story.uuid,
      timestamp: story.inserted_at |> Time.naive_to_epoch(),
      operating_cities: story.operating_cities,
      possession_by: story.possession_by |> Time.naive_to_epoch(),
      thumbnail_image_url: story.thumbnail_image_url,
      new_story_thumbnail_image_url: story.new_story_thumbnail_image_url,
      project_logo_url: story.project_logo_url,
      is_rewards_enabled: story.is_rewards_enabled,
      is_manually_deacticated_for_rewards: story.is_manually_deacticated_for_rewards,
      is_cab_booking_enabled: story.is_cab_booking_enabled,
      developer_pocs: developer_pocs_response,
      project_type_id: project_type_id,
      locality: locality,
      polygon: polygon,
      story_tier_id: story.story_tier_id,
      rera_ids: story.rera_ids
    }
  end

  @doc """
  {
    title: <name of developer>,
    thumbnail: <thumb image url>,
    developer_logo: <developer logo url>,
    uuid: <story uuid>,
    interval: <time in seconds to show a slide of story>,
    timestamp: <epoch time, when this story was created>,
    favourite: <boolean>,
    archived: <boolean>,
    seen: <boolean>,
    sections: [
      story_section,
      story_section,
      ...
    ]
  }
  """
  def render("story_admin.json", %{story: story, user_id: user_id}) do
    story =
      story
      |> Repo.preload([
        :user_favourites,
        :story_sections,
        :story_sales_kits,
        :story_project_configs,
        :developer,
        :project_type,
        :rewards_bn_poc,
        :sv_business_development_manager,
        :sv_implementation_manager,
        :sv_market_head,
        :sv_cluster_head,
        :sv_account_manager,
        :polygon,
        :story_developer_poc_mappings,
        priority_stories: from(ps in PriorityStory, where: ps.active == true),
        story_developer_poc_mappings: [:developer_poc_credential]
      ])

    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits =
      render_many(story.story_sales_kits, StoryView, "story_sales_kit.json", %{
        user_id: user_id
      })

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

    rewards_bn_poc = get_employee_details(story.rewards_bn_poc)
    sv_business_development_manager = get_employee_details(story.sv_business_development_manager)
    sv_implementation_manager = get_employee_details(story.sv_implementation_manager)
    sv_market_head = get_employee_details(story.sv_market_head)
    sv_cluster_head = get_employee_details(story.sv_cluster_head)
    sv_account_manager = get_employee_details(story.sv_account_manager)

    polygon =
      case story.polygon do
        nil ->
          nil

        polygon ->
          render_one(polygon, BnApisWeb.PolygonView, "polygon_basic.json")
      end

    project_type_id = if not is_nil(story.project_type), do: story.project_type.id, else: nil

    developer_pocs = BnApis.Stories.Story.get_developer_pocs(story)

    developer_pocs_response =
      BnApisWeb.CredentialView.render("developer_pocs_data.json", %{
        data: developer_pocs
      })

    balances = BnApis.Stories.Story.get_story_balances(story)
    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

    %{
      story_id: story.id,
      default_story_tier_id: story.default_story_tier_id,
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
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      is_booking_reward_enabled: story.is_booking_reward_enabled,
      is_booking_reward_enabled_on_app:
        story.is_booking_reward_enabled and not is_nil(story.rera_ids) and length(story.rera_ids) > 0 and
          length(legal_entities) > 0,
      blocked_for_reward_approval: story.blocked_for_reward_approval,
      invoicing_type: story.invoicing_type,
      brokerage_proof_url: story.brokerage_proof_url,
      advanced_brokerage_percent: story.advanced_brokerage_percent,
      rera_ids: story.rera_ids,
      total_rewards_amount: story.total_rewards_amount,
      total_credits_amount: balances[:total_credits_amount],
      total_debits_amount: balances[:total_debits_amount],
      total_pending_amount: balances[:total_pending_amount],
      total_approved_amount: balances[:total_approved_amount],
      total_pending_or_approved_amount: (balances[:total_pending_amount] || 0) + (balances[:total_approved_amount] || 0),
      latitude: story.latitude,
      longitude: story.longitude,
      google_maps_url: story.google_maps_url,
      marketing_kit_url: story.marketing_kit_url,
      rewards_bn_poc: rewards_bn_poc,
      sv_business_development_manager: sv_business_development_manager,
      sv_implementation_manager: sv_implementation_manager,
      sv_market_head: sv_market_head,
      sv_cluster_head: sv_cluster_head,
      sv_account_manager: sv_account_manager,
      polygon: polygon,
      developer_pocs: developer_pocs_response,
      project_type_id: project_type_id,
      story_tier_id: story.story_tier_id,
      story_tier_plan_mapping: story.story_tier_plan_mapping,
      legal_entities: story.legal_entities,
      disabled_rewards_reason: story.disabled_rewards_reason,
      on_priority: length(story.priority_stories) > 0,
      has_mandate_company: story.has_mandate_company,
      mandate_company_id: story.mandate_company_id,
      mandate_company: MandateCompanies.fetch_and_parse_mandate_company(story.mandate_company_id)
    }
  end

  def render("story_api.json", %{story: story, user_id: user_id}) do
    story =
      story
      |> Repo.preload([
        :user_favourites,
        :story_sections,
        :story_sales_kits,
        :story_project_configs,
        :developer,
        :project_type,
        :rewards_bn_poc,
        :sv_business_development_manager,
        :sv_implementation_manager,
        :sv_market_head,
        :sv_cluster_head,
        :sv_account_manager,
        :polygon,
        :story_developer_poc_mappings,
        story_developer_poc_mappings: [:developer_poc_credential]
      ])

    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits =
      render_many(story.story_sales_kits, StoryView, "story_sales_kit_api.json", %{
        user_id: user_id
      })

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

    rewards_bn_poc = get_employee_details(story.rewards_bn_poc)
    sv_business_development_manager = get_employee_details(story.sv_business_development_manager)
    sv_implementation_manager = get_employee_details(story.sv_implementation_manager)
    sv_market_head = get_employee_details(story.sv_market_head)
    sv_cluster_head = get_employee_details(story.sv_cluster_head)
    sv_account_manager = get_employee_details(story.sv_account_manager)

    polygon =
      case story.polygon do
        nil ->
          nil

        polygon ->
          render_one(polygon, BnApisWeb.PolygonView, "polygon_basic.json")
      end

    project_type_id = if not is_nil(story.project_type), do: story.project_type.id, else: nil

    developer_pocs = BnApis.Stories.Story.get_developer_pocs(story)

    developer_pocs_response =
      BnApisWeb.CredentialView.render("developer_pocs_data.json", %{
        data: developer_pocs
      })

    balances = BnApis.Stories.Story.get_story_balances(story)
    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

    %{
      story_id: story.id,
      default_story_tier_id: story.default_story_tier_id,
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
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      blocked_for_reward_approval: story.blocked_for_reward_approval,
      invoicing_type: story.invoicing_type,
      brokerage_proof_url: story.brokerage_proof_url,
      advanced_brokerage_percent: story.advanced_brokerage_percent,
      rera_ids: story.rera_ids,
      total_rewards_amount: story.total_rewards_amount,
      total_credits_amount: balances[:total_credits_amount],
      total_debits_amount: balances[:total_debits_amount],
      total_pending_amount: balances[:total_pending_amount],
      total_approved_amount: balances[:total_approved_amount],
      total_pending_or_approved_amount: (balances[:total_pending_amount] || 0) + (balances[:total_approved_amount] || 0),
      latitude: story.latitude,
      longitude: story.longitude,
      google_maps_url: story.google_maps_url,
      marketing_kit_url: story.marketing_kit_url,
      rewards_bn_poc: rewards_bn_poc,
      sv_business_development_manager: sv_business_development_manager,
      sv_implementation_manager: sv_implementation_manager,
      sv_market_head: sv_market_head,
      sv_cluster_head: sv_cluster_head,
      sv_account_manager: sv_account_manager,
      polygon: polygon,
      developer_pocs: developer_pocs_response,
      project_type_id: project_type_id,
      story_tier_id: story.story_tier_id,
      story_tier_plan_mapping: story.story_tier_plan_mapping,
      legal_entities: legal_entities,
      is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities)
    }
  end

  def render("story_api_new.json", %{story: story, user_id: user_id}) do
    story =
      story
      |> Repo.preload([
        :user_favourites,
        :story_sections,
        :story_sales_kits,
        :story_project_configs,
        :developer,
        :project_type,
        :rewards_bn_poc,
        :sv_business_development_manager,
        :sv_implementation_manager,
        :sv_market_head,
        :sv_cluster_head,
        :sv_account_manager,
        :polygon,
        :story_developer_poc_mappings,
        story_developer_poc_mappings: [:developer_poc_credential]
      ])

    user_favourite =
      story.user_favourites
      |> Enum.filter(&(&1.credential_id == user_id and &1.timestamp))
      |> List.first()

    sections =
      render_many(story.story_sections, StoryView, "story_section.json", %{
        user_id: user_id
      })

    sales_kits = Stories.create_map_for_story_sales_kits(story.story_sales_kits)

    project_configs =
      render_many(story.story_project_configs, StoryView, "story_project_config.json", %{
        user_id: user_id
      })

    rewards_bn_poc = get_employee_details(story.rewards_bn_poc)
    sv_business_development_manager = get_employee_details(story.sv_business_development_manager)
    sv_implementation_manager = get_employee_details(story.sv_implementation_manager)
    sv_market_head = get_employee_details(story.sv_market_head)
    sv_cluster_head = get_employee_details(story.sv_cluster_head)
    sv_account_manager = get_employee_details(story.sv_account_manager)

    polygon =
      case story.polygon do
        nil ->
          nil

        polygon ->
          render_one(polygon, BnApisWeb.PolygonView, "polygon_basic.json")
      end

    project_type_id = if not is_nil(story.project_type), do: story.project_type.id, else: nil

    developer_pocs = BnApis.Stories.Story.get_developer_pocs(story)

    developer_pocs_response =
      BnApisWeb.CredentialView.render("developer_pocs_data.json", %{
        data: developer_pocs
      })

    balances = BnApis.Stories.Story.get_story_balances(story)
    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

    %{
      story_id: story.id,
      default_story_tier_id: story.default_story_tier_id,
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
      is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular",
      is_invoicing_enabled: story.is_invoicing_enabled,
      is_enabled_for_commercial: story.is_enabled_for_commercial,
      blocked_for_reward_approval: story.blocked_for_reward_approval,
      invoicing_type: story.invoicing_type,
      brokerage_proof_url: story.brokerage_proof_url,
      advanced_brokerage_percent: story.advanced_brokerage_percent,
      rera_ids: story.rera_ids,
      total_rewards_amount: story.total_rewards_amount,
      total_credits_amount: balances[:total_credits_amount],
      total_debits_amount: balances[:total_debits_amount],
      total_pending_amount: balances[:total_pending_amount],
      total_approved_amount: balances[:total_approved_amount],
      total_pending_or_approved_amount: (balances[:total_pending_amount] || 0) + (balances[:total_approved_amount] || 0),
      latitude: story.latitude,
      longitude: story.longitude,
      google_maps_url: story.google_maps_url,
      marketing_kit_url: story.marketing_kit_url,
      rewards_bn_poc: rewards_bn_poc,
      sv_business_development_manager: sv_business_development_manager,
      sv_implementation_manager: sv_implementation_manager,
      sv_market_head: sv_market_head,
      sv_cluster_head: sv_cluster_head,
      sv_account_manager: sv_account_manager,
      polygon: polygon,
      developer_pocs: developer_pocs_response,
      project_type_id: project_type_id,
      story_tier_id: story.story_tier_id,
      story_tier_plan_mapping: story.story_tier_plan_mapping,
      legal_entities: legal_entities,
      is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities)
    }
  end

  @doc """
  {
    uuid: <section uuid>,
    interval: <override in time in seconds to show a slide of story>,
    type: <image/video>,
    resource_url: <url to point to image/video>,
    seen: <boolean>
  }
  """
  def render("story_section.json", %{story: section, user_id: _user_id}) do
    %{
      uuid: section.uuid,
      interval: section.interval,
      type: section.resource_type_id,
      order: section.order,
      resource_type_id: section.resource_type_id,
      resource_url: section.resource_url,
      seen: false,
      active: section.active
      # seen: not is_nil(section.seen_at),
    }
  end

  @doc """
  {
    uuid: <attachment uuid>,
    name: <name of attachment>,
    thumbnail: <url for preview thumb of attachment>,
    share_url: <url for sharing - will be shortened>,
    preview_url: <url for showing preview/downloading>,
    size_in_mb: <filesize in MB>,
    type: <image/pdf/video>,
  }
  """
  def render("story_sales_kit.json", %{story: attachment, user_id: _user_id}) do
    size_in_mb = if is_nil(attachment.size_in_mb), do: attachment.size_in_mb, else: attachment.size_in_mb |> Decimal.to_float()

    %{
      uuid: attachment.uuid,
      name: attachment.name,
      thumbnail: attachment.thumbnail,
      share_url: attachment.share_url,
      preview_url: attachment.preview_url,
      size_in_mb: size_in_mb,
      type: attachment.attachment_type_id,
      attachment_type_id: attachment.attachment_type_id,
      active: attachment.active,
      youtube_url: attachment.youtube_url
    }
  end

  def render("story_sales_kit_api.json", %{story: sales_kit, user_id: _user_id}) do
    size_in_mb = if is_nil(sales_kit.size_in_mb), do: sales_kit.size_in_mb, else: sales_kit.size_in_mb |> Decimal.to_float()

    %{
      uuid: sales_kit.uuid,
      name: sales_kit.name,
      thumbnail: sales_kit.thumbnail,
      share_url: sales_kit.share_url,
      preview_url: sales_kit.preview_url,
      size_in_mb: size_in_mb,
      type: sales_kit.attachment_type_id,
      attachment_type_id: sales_kit.attachment_type_id,
      active: sales_kit.active
    }
  end

  @doc """
  {
    uuid: <project_config uuid>,
    carpet_area: <project_config carpet_area>,
    starting_price: <project_config starting_price>,
    configuration_type_id: <project_config configuration_type_id>,
    active: <project_config active>
  }
  """
  def render("story_project_config.json", %{story: project_config, user_id: _user_id}) do
    project_config =
      project_config
      |> Repo.preload([:configuration_type])

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
  end

  def get_employee_details(employee) do
    case employee do
      nil ->
        nil

      entity ->
        render_one(
          entity,
          BnApisWeb.EmployeeCredentialView,
          "employee_credential.json"
        )
    end
  end
end
