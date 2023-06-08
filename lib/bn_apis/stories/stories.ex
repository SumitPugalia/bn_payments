defmodule BnApis.Stories do
  @moduledoc """
  The Stories context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Accounts
  alias BnApis.Repo
  alias BnApis.Helpers.{Time, S3Helper, ApplicationHelper, AuditedRepo, Utils, Redis}

  alias BnApis.Stories.{
    SectionResourceType,
    Story,
    StorySection,
    StorySalesKit,
    StoryProjectConfig,
    UserSeen,
    UserFavourite,
    StoryDeveloperPocMapping,
    StoryLegalEntityMapping
  }

  alias BnApis.Rewards.StoryTier
  alias BnApis.Developers.Developer
  alias BnApis.Helpers.ErrorHelper
  alias BnApis.Rewards.StoryTierPlanMapping
  alias BnApis.Rewards
  alias BnApis.Stories.Schema.PriorityStory
  alias BnApis.Projects.NewStoryCreativesPushNotificationWorker
  alias BnApis.Places.City

  @youtube_thumbnail_url "https://img.youtube.com/vi/"
  @youtube_thumbnail_default_img "/hqdefault.jpg"

  def mark_seen(user_uuid, story_uuid, section_uuid, timestamp) do
    case Accounts.get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        case Story.story_section_query(story_uuid, section_uuid)
             |> Repo.one() do
          nil ->
            {:error, "Story section not found!"}

          story_section ->
            mark_seen_params = %{
              credential_id: credential.id,
              story_id: story_section.story_id,
              story_section_id: story_section.id,
              timestamp: timestamp |> Time.epoch_to_naive()
            }

            UserSeen.changeset(%UserSeen{}, mark_seen_params)
            |> Repo.insert(on_conflict: :nothing)
        end
    end
  end

  def mark_favourite(user_uuid, story_uuid, timestamp) do
    case Accounts.get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        case Repo.get_by(Story, uuid: story_uuid) do
          nil ->
            {:error, "Story not found!"}

          story ->
            case Story.user_favourite_query(credential.id, story.id)
                 |> Repo.one() do
              nil ->
                mark_favourite_params = %{
                  credential_id: credential.id,
                  story_id: story.id,
                  timestamp: timestamp |> Time.epoch_to_naive()
                }

                %UserFavourite{}
                |> UserFavourite.changeset(mark_favourite_params)
                |> Repo.insert(on_conflict: :nothing)

              user_favourite ->
                mark_favourite_params = %{
                  timestamp: timestamp |> Time.epoch_to_naive()
                }

                user_favourite
                |> UserFavourite.changeset(mark_favourite_params)
                |> Repo.update()
            end
        end
    end
  end

  def remove_favourite(user_uuid, story_uuid) do
    case Accounts.get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        case Repo.get_by(Story, uuid: story_uuid) do
          nil ->
            {:error, "Story not found!"}

          story ->
            case Story.user_favourite_query(credential.id, story.id)
                 |> Repo.one() do
              nil ->
                {:error, "Story cannot be unfavourited!"}

              user_favourite ->
                remove_favourite_params = %{
                  timestamp: nil
                }

                UserFavourite.changeset(user_favourite, remove_favourite_params)
                |> Repo.update()
            end
        end
    end
  end

  def fetch_all_stories(page, user_operating_city, filters \\ %{}) do
    query = Story.filter_story_query(filters, user_operating_city, filters["exclude_story_uuids"])
    total_count = query |> Repo.all() |> length()

    limit_query = query |> Story.add_limit(page)

    active_story_sections_query = from section in StorySection, where: section.active == true
    story_project_configs_query = from project_config in StoryProjectConfig, where: project_config.active == true, distinct: project_config.configuration_type_id

    stories =
      limit_query
      |> preload([
        :user_favourites,
        :story_sales_kits,
        :developer,
        :polygon,
        :story_developer_poc_mappings,
        priority_stories: ^from(ps in PriorityStory, where: ps.active == true and ps.city_id == ^user_operating_city),
        story_developer_poc_mappings: [:developer_poc_credential],
        story_project_configs: [:configuration_type],
        story_project_configs: ^story_project_configs_query,
        story_sections: ^active_story_sections_query
      ])
      |> Repo.all()

    has_more_stories = length(stories) - Story.per_page() == 0

    {stories, has_more_stories, total_count}
  end

  def fetch_all_favourite_stories(cred_id, page) do
    query = Story.all_favourite_query(cred_id)

    total_count = query |> Story.get_count()
    has_more_stories = page < Float.ceil(total_count / Story.per_page())

    limit_query = query |> Story.add_limit(page)

    stories =
      limit_query
      |> preload([
        :user_favourites,
        :story_sales_kits,
        :story_project_configs,
        :developer,
        :polygon,
        :story_developer_poc_mappings,
        story_developer_poc_mappings: [:developer_poc_credential]
      ])
      |> Repo.all()

    {stories, has_more_stories}
  end

  def fetch_rewards_enables_stories(user_operating_city) do
    Story.rewards_enabled_query(user_operating_city)
    |> Repo.all()
    |> Enum.map(&Story.get_story_details_for_rewards(&1, true))
  end

  def create_story_tier(amount, name, is_default, user_id) do
    {status, tier} = StoryTier.create_story_tier(amount, name, is_default, user_id)

    if status == :ok do
      if is_default == true do
        StoryTier
        |> where([st], st.id != ^tier.id)
        |> Repo.all()
        |> Enum.each(fn str ->
          str |> StoryTier.changeset(%{"is_default" => false}) |> Repo.update!()
        end)
      end

      {:ok, StoryTier.get_tier_data(tier)}
    else
      {:unprocessable_entity, ErrorHelper.get_changeset_error(tier)}
    end
  end

  @doc """
  Returns the list of stories_section_resource_types.

  ## Examples

      iex> list_stories_section_resource_types()
      [%SectionResourceType{}, ...]

  """
  def list_stories_section_resource_types do
    Repo.all(SectionResourceType)
  end

  @doc """
  Gets a single section_resource_type.

  Raises `Ecto.NoResultsError` if the Section resource type does not exist.

  ## Examples

      iex> get_section_resource_type!(123)
      %SectionResourceType{}

      iex> get_section_resource_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_section_resource_type!(id), do: Repo.get!(SectionResourceType, id)

  @doc """
  Creates a section_resource_type.

  ## Examples

      iex> create_section_resource_type(%{field: value})
      {:ok, %SectionResourceType{}}

      iex> create_section_resource_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_section_resource_type(attrs \\ %{}) do
    %SectionResourceType{}
    |> SectionResourceType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section_resource_type.

  ## Examples

      iex> update_section_resource_type(section_resource_type, %{field: new_value})
      {:ok, %SectionResourceType{}}

      iex> update_section_resource_type(section_resource_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_section_resource_type(
        %SectionResourceType{} = section_resource_type,
        attrs
      ) do
    section_resource_type
    |> SectionResourceType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SectionResourceType.

  ## Examples

      iex> delete_section_resource_type(section_resource_type)
      {:ok, %SectionResourceType{}}

      iex> delete_section_resource_type(section_resource_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_section_resource_type(%SectionResourceType{} = section_resource_type) do
    Repo.delete(section_resource_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking section_resource_type changes.

  ## Examples

      iex> change_section_resource_type(section_resource_type)
      %Ecto.Changeset{source: %SectionResourceType{}}

  """
  def change_section_resource_type(%SectionResourceType{} = section_resource_type) do
    SectionResourceType.changeset(section_resource_type, %{})
  end

  @doc """
  Returns the list of stories_sections.

  ## Examples

      iex> list_stories_sections()
      [%StorySection{}, ...]

  """
  def list_stories_sections do
    Repo.all(StorySection)
  end

  @doc """
  Gets a single story_section.

  Raises `Ecto.NoResultsError` if the Story section does not exist.

  ## Examples

      iex> get_story_section!(123)
      %StorySection{}

      iex> get_story_section!(456)
      ** (Ecto.NoResultsError)

  """
  def get_story_section!(id), do: Repo.get!(StorySection, id)

  def get_story_section_by_uuid!(uuid),
    do: Repo.get_by!(StorySection, uuid: uuid)

  @doc """
  Creates a story_section.

  ## Examples

      iex> create_story_section(%{field: value})
      {:ok, %StorySection{}}

      iex> create_story_section(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story_section(attrs \\ %{}) do
    %StorySection{}
    |> StorySection.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a story_section.

  ## Examples

      iex> update_story_section(story_section, %{field: new_value})
      {:ok, %StorySection{}}

      iex> update_story_section(story_section, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_story_section(%StorySection{} = story_section, attrs) do
    story_section
    |> StorySection.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a StorySection.

  ## Examples

      iex> delete_story_section(story_section)
      {:ok, %StorySection{}}

      iex> delete_story_section(story_section)
      {:error, %Ecto.Changeset{}}

  """
  def delete_story_section(%StorySection{} = story_section) do
    Repo.delete(story_section)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story_section changes.

  ## Examples

      iex> change_story_section(story_section)
      %Ecto.Changeset{source: %StorySection{}}

  """
  def change_story_section(%StorySection{} = story_section) do
    StorySection.changeset(story_section, %{})
  end

  alias BnApis.Stories.Story

  @doc """
  Returns the list of stories.

  ## Examples

      iex> list_stories()
      [%Story{}, ...]

  """

  def list_stories(params) do
    limit = 50
    page_no = (params["p"] || "1") |> String.to_integer()
    offset = (page_no - 1) * limit
    query = params["q"]
    operating_city_id = Map.get(params, "operating_city_id")

    stories =
      Story
      |> join(:left, [s], dev in Developer, on: s.developer_id == dev.id)
      |> join(:left, [s, dev], ps in PriorityStory, on: ps.story_id == s.id and ps.active == true)

    stories = add_operating_city_filter(operating_city_id, stories)

    stories =
      if !is_nil(query) && is_binary(query) && String.trim(query) != "" do
        formatted_query = "%#{String.downcase(String.trim(query))}%"

        stories
        |> where(
          [s, dev],
          fragment("LOWER(?) LIKE ?", s.name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", s.phone_number, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", s.contact_person_name, ^formatted_query) or
            fragment("LOWER(?) LIKE ?", dev.name, ^formatted_query)
        )
      else
        stories
      end

    stories =
      stories
      |> offset(^offset)
      |> limit(^(limit + 1))
      |> order_by([s, dev, ps], asc: ps.priority, desc: s.id)
      |> Repo.all()

    # adding story_tier_plan_mapping key and updating story_tier_id key using the plans
    updated_stories =
      stories
      |> Enum.map(fn story ->
        story_tier_id = Rewards.get_story_tier_id_from_plans(story.id)

        story_tier_id =
          if is_nil(story_tier_id) do
            story.default_story_tier_id
          else
            story_tier_id
          end

        story_with_story_tier_id = Map.put(story, :story_tier_id, story_tier_id)

        story_tier_plan_mapping = StoryTierPlanMapping.get_story_tier_plans(story.id)

        story_with_story_tier_plan_mapping = Map.put(story_with_story_tier_id, :story_tier_plan_mapping, story_tier_plan_mapping)

        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
        Map.put(story_with_story_tier_plan_mapping, :legal_entities, legal_entities)
      end)

    %{
      stories: Enum.take(updated_stories, limit),
      has_next_page: length(stories) > limit
    }
  end

  @doc """
  Gets a single story.

  Raises `Ecto.NoResultsError` if the Story does not exist.

  ## Examples

      iex> get_story!(123)
      %Story{}

      iex> get_story!(456)
      ** (Ecto.NoResultsError)

  """

  def get_story(id, preloads \\ []), do: Story |> where([s], s.id == ^id) |> preload(^preloads) |> Repo.one()

  def get_story_from_uuid!(uuid, is_admin_call \\ false) do
    active_story_sections_query =
      if is_admin_call == false do
        from section in StorySection, where: section.active == true
      else
        from(section in StorySection)
      end

    story =
      Repo.get_by!(Story, uuid: uuid)
      |> Repo.preload([:story_sales_kits, :story_project_configs, story_sections: active_story_sections_query])

    story_tier_plan_mapping = StoryTierPlanMapping.get_story_tier_plans(story.id)
    updated_story = Map.put(story, :story_tier_plan_mapping, story_tier_plan_mapping)

    # update story_tier_id according to the plan
    story_tier_id = Rewards.get_story_tier_id_from_plans(story.id)

    story_tier_id =
      if is_nil(story_tier_id) do
        story.default_story_tier_id
      else
        story_tier_id
      end

    updated_story = Map.put(updated_story, :story_tier_id, story_tier_id)

    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
    Map.put(updated_story, :legal_entities, legal_entities)
  end

  def get_story_suggestions(
        user_id,
        user_operating_city,
        params,
        parse_youtube_urls \\ false
      ) do
    search_text = if is_nil(params["q"]), do: "", else: params["q"] |> String.downcase()

    exclude_story_uuids = params["exclude_story_uuids"]

    exclude_story_uuids =
      if is_nil(exclude_story_uuids) or exclude_story_uuids == "",
        do: [],
        else: exclude_story_uuids |> String.split(",")

    flags = %{
      is_rewards_enabled: params["is_rewards_enabled"] == "true",
      is_cab_booking_enabled: params["is_cab_booking_enabled"] == "true"
    }

    suggestions =
      Story.search_story_query(
        search_text,
        user_operating_city,
        exclude_story_uuids,
        flags
      )
      |> Repo.all()

    if params["is_rewards_enabled"] == "true" or params["is_cab_booking_enabled"] == "true" do
      suggestions
      |> Enum.map(fn story ->
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

        project_type_id = story.project_type_id
        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
        operating_city = City.get_city_by_id(user_operating_city)

        %{
          title: story.developer.name,
          developer_name: story.developer.name,
          developer_uuid: story.developer.uuid,
          sub_title: story.name,
          name: story.name,
          thumbnail: story.image_url,
          developer_logo: story.developer.logo_url,
          id: story.id,
          uuid: story.uuid,
          timestamp: story.inserted_at |> Time.naive_to_epoch(),
          operating_cities: story.operating_cities,
          project_configs: project_configs,
          configuration_type_ids: story.configuration_type_ids,
          possession_by: story.possession_by |> Time.naive_to_epoch(),
          thumbnail_image_url: story.thumbnail_image_url,
          new_story_thumbnail_image_url: story.new_story_thumbnail_image_url,
          project_logo_url: story.project_logo_url,
          is_rewards_enabled: story.is_rewards_enabled,
          is_cab_booking_enabled: story.is_cab_booking_enabled,
          is_advance_brokerage_enabled: story.is_invoicing_enabled && story.invoicing_type == "advanced" && operating_city.feature_flags["invoice"] == true,
          is_invoice_rewards_enabled: story.is_invoicing_enabled && story.invoicing_type == "regular" && operating_city.feature_flags["invoice"] == true,
          is_invoicing_enabled: story.is_invoicing_enabled,
          is_enabled_for_commercial: story.is_enabled_for_commercial,
          invoicing_type: story.invoicing_type,
          brokerage_proof_url: story.brokerage_proof_url,
          advanced_brokerage_percent: story.advanced_brokerage_percent,
          developer_pocs: developer_pocs_response,
          project_type_id: project_type_id,
          locality: locality,
          polygon: polygon,
          avg_cost_per_sq_ft: calculate_avg_cost_per_sq_ft(story.story_project_configs),
          story_tier_id: story.story_tier_id,
          is_booking_reward_enabled: Story.get_is_booking_reward_enabled_on_app(story, legal_entities) && operating_city.feature_flags["booking_rewards"] == true,
          legal_entities: legal_entities,
          gate_pass: story.gate_pass,
          rera_ids: story.rera_ids
        }
      end)
    else
      case parse_youtube_urls do
        true ->
          suggestions
          |> Enum.map(fn story ->
            story_json_map = BnApisWeb.StoryView.render("story.json", %{story: story, user_id: user_id})

            story = story |> Repo.preload([:story_sales_kits])
            sales_kits_json_map = create_map_for_story_sales_kits(story.story_sales_kits)
            Map.put(story_json_map, :sales_kits, sales_kits_json_map)
          end)

        false ->
          suggestions
          |> Enum.map(fn story ->
            story_json_map = BnApisWeb.StoryView.render("story.json", %{story: story, user_id: user_id})

            sales_kits_json =
              story_json_map
              |> Map.get(:sales_kits, [])
              |> filter_youtube_urls()

            Map.put(story_json_map, :sales_kits, sales_kits_json)
          end)
      end
    end
  end

  def get_story_legal_entity_suggestions(params, operating_city_id) do
    page_no = (params["p"] || "1") |> String.to_integer()
    get_paginated_search_results(page_no, params, operating_city_id)
  end

  defp get_paginated_search_results(page_no, params, operating_city_id) do
    limit = 30
    offset = (page_no - 1) * limit

    search_text = if is_nil(params["q"]), do: "", else: params["q"] |> String.downcase()

    br_flag =
      if is_nil(params["booking_reward_flag"]) or params["booking_reward_flag"] == "",
        do: nil,
        else: params["booking_reward_flag"] |> Utils.parse_boolean_param()

    inv_flag =
      if is_nil(params["invoice_flag"]) or params["invoice_flag"] == "",
        do: nil,
        else: params["invoice_flag"] |> Utils.parse_boolean_param()

    exclude_story_uuids = params["exclude_story_uuids"]

    exclude_story_uuids =
      if is_nil(exclude_story_uuids) or exclude_story_uuids == "",
        do: [],
        else: exclude_story_uuids |> String.split(",")

    suggestions =
      Story.search_story_legal_entity_query(
        search_text,
        exclude_story_uuids,
        operating_city_id,
        limit,
        offset,
        br_flag,
        inv_flag
      )
      |> Repo.all()

    suggestions_per_page =
      suggestions
      |> Enum.map(fn story ->
        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)

        locality =
          case story.polygon do
            %{name: name} ->
              name

            _ ->
              nil
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

        %{
          name: story.name,
          uuid: story.uuid,
          id: story.id,
          developer_name: story.developer.name,
          rera_ids: story.rera_ids,
          operating_cities: story.operating_cities,
          locality: locality,
          polygon: polygon,
          avg_cost_per_sq_ft: calculate_avg_cost_per_sq_ft(story.story_project_configs),
          legal_entities: legal_entities
        }
      end)

    %{
      "next_page_exists" => Enum.count(suggestions) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}",
      "suggestions" => suggestions_per_page
    }
  end

  def get_admin_story_suggestions(
        search_text,
        exclude_story_uuids \\ [],
        city_id \\ nil,
        is_cab_booking_enabled \\ nil
      ) do
    Story.admin_search_story_query(
      search_text,
      exclude_story_uuids,
      city_id,
      is_cab_booking_enabled
    )
    |> Repo.all()
  end

  def filter_story_suggestions(
        filters,
        user_id,
        user_operating_city,
        exclude_story_uuids \\ []
      ) do
    suggestions =
      Story.filter_story_query(filters, user_operating_city, exclude_story_uuids)
      |> Story.add_limit(filters["page"])
      |> Repo.all()

    suggestions_with_legal_entities =
      suggestions
      |> Enum.map(fn story ->
        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
        Map.put(story, :legal_entities, legal_entities)
      end)

    suggestions_with_legal_entities
    |> Enum.map(&BnApisWeb.StoryView.render("story.json", %{story: &1, user_id: user_id}))
  end

  def filter_story_suggestions_count(
        filters,
        _user_id,
        user_operating_city,
        exclude_story_uuids \\ []
      ) do
    Story.filter_story_query_count(
      filters,
      user_operating_city,
      exclude_story_uuids
    )
  end

  @doc """
  Creates a story.

  ## Examples

      iex> create_story(%{field: value})
      {:ok, %Story{}}

      iex> create_story(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story(attrs, user_map \\ %{}) do
    Repo.transaction(fn ->
      try do
        {:ok, story} = %Story{} |> Story.changeset(attrs) |> AuditedRepo.insert(user_map)

        case attrs["legal_entity_ids"] do
          legal_entity_ids when is_list(legal_entity_ids) ->
            assign_legal_entity_ids_to_story(story, legal_entity_ids)
            story

          _ ->
            story
        end

        Exq.enqueue(Exq, "sendbird", BnApis.RegisterUserOnSendbird, [
          Story.get_sendbird_payload(story)
        ])

        is_invoicing_enabled = story.is_invoicing_enabled

        story_has_legal_entities? = not Enum.empty?(StoryLegalEntityMapping.get_legal_entities_for_story(story.id))

        if is_invoicing_enabled do
          if story_has_legal_entities?,
            do: story,
            else: raise("Story should have at least one legal entity associated to it.")
        else
          story
        end
      rescue
        _ ->
          Repo.rollback("Something went wrong while story creation. Unable to store data")
      end
    end)
  end

  @doc """
  Updates a story.

  ## Examples

      iex> update_story(story, %{field: new_value})
      {:ok, %Story{}}

      iex> update_story(story, %{field: bad_value})
      {:error, %{message: ""}}

  """
  def update_story(%Story{} = story, attrs, user_map) do
    Repo.transaction(fn ->
      try do
        changeset = Story.changeset(story, attrs)
        {:ok, story} = AuditedRepo.update(changeset, user_map)

        case Map.get(changeset.changes, :is_rewards_enabled) do
          nil -> :ok
          true -> Redis.q(["LPUSH", "sv_rewards_activated_last_week", story.id])
          false -> Redis.q(["LREM", "sv_rewards_activated_last_week", 1, story.id])
        end

        case Map.get(changeset.changes, :is_booking_reward_enabled) do
          nil -> :ok
          true -> Redis.q(["LPUSH", "booking_rewards_activated_last_week", story.id])
          false -> Redis.q(["LREM", "booking_rewards_activated_last_week", 1, story.id])
        end

        Exq.enqueue(Exq, "sendbird", BnApis.UpdateUserOnSendbird, [
          Story.get_sendbird_payload(story, true),
          story.uuid,
          Story.get_sendbird_metadata_payload(story)
        ])

        case attrs["developer_poc_ids"] do
          developer_poc_ids when is_list(developer_poc_ids) ->
            assign_developer_poc_ids!(
              story,
              developer_poc_ids,
              user_map[:user_id],
              user_map[:user_type]
            )

            story

          _ ->
            story
        end

        send_new_creative_notif? = Map.get(attrs, "send_new_creative_notif", "false") |> Utils.parse_boolean_param()

        if send_new_creative_notif? do
          Task.async(fn -> NewStoryCreativesPushNotificationWorker.perform(story) end)
        end

        case attrs["legal_entity_ids"] do
          legal_entity_ids when is_list(legal_entity_ids) ->
            assign_legal_entity_ids_to_story(story, legal_entity_ids)
            story

          _ ->
            story
        end

        legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
        story_map = Map.put(story, :legal_entities, legal_entities)

        is_invoicing_enabled = story.is_invoicing_enabled
        story_has_legal_entities? = not Enum.empty?(legal_entities)

        if is_invoicing_enabled do
          if story_has_legal_entities?,
            do: story_map,
            else: raise("Story should have at least one legal entity associated to it.")
        else
          story_map
        end
      rescue
        err ->
          Repo.rollback(err)
      end
    end)
  end

  def assign_developer_poc_ids!(story, developer_poc_ids, user_id, user_type) do
    story = story |> Repo.preload(:story_developer_poc_mappings)

    active_developer_poc_credential_ids =
      story.story_developer_poc_mappings
      |> Enum.filter(&(&1.active == true))
      |> Enum.map(& &1.developer_poc_credential_id)

    developer_poc_ids_to_be_added = developer_poc_ids -- active_developer_poc_credential_ids

    developer_poc_ids_to_be_removed = active_developer_poc_credential_ids -- developer_poc_ids

    developer_poc_ids_to_be_added
    |> Enum.each(fn developer_poc_id ->
      StoryDeveloperPocMapping.activate_story_developer_poc_mapping!(
        story.id,
        developer_poc_id,
        user_id,
        user_type
      )
    end)

    developer_poc_ids_to_be_removed
    |> Enum.each(fn developer_poc_id ->
      StoryDeveloperPocMapping.deactivate_story_developer_poc_mapping!(
        story.id,
        developer_poc_id,
        user_id,
        user_type
      )
    end)
  end

  def assign_legal_entity_ids_to_story(story, legal_entity_ids) do
    current_active_legal_entity_ids = StoryLegalEntityMapping.get_active_legal_entities_for_story(story.id)

    legal_entities_to_be_activated = legal_entity_ids -- current_active_legal_entity_ids
    legal_entities_to_be_deactivated = current_active_legal_entity_ids -- legal_entity_ids

    legal_entities_to_be_activated
    |> Enum.each(fn legal_entity_id ->
      StoryLegalEntityMapping.activate_story_legal_entity_mapping(story.id, legal_entity_id)
    end)

    legal_entities_to_be_deactivated
    |> Enum.each(fn legal_entity_id ->
      StoryLegalEntityMapping.deactivate_story_legal_entity_mapping(story.id, legal_entity_id)
    end)
  end

  @doc """
  Deletes a Story.

  ## Examples

      iex> delete_story(story)
      {:ok, %Story{}}

      iex> delete_story(story)
      {:error, %Ecto.Changeset{}}

  """
  def delete_story(%Story{} = story, user_map) do
    AuditedRepo.delete(story, user_map)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story changes.

  ## Examples

      iex> change_story(story)
      %Ecto.Changeset{source: %Story{}}

  """
  def change_story(%Story{} = story) do
    Story.changeset(story, %{})
  end

  alias BnApis.Stories.StorySalesKit

  @doc """
  Returns the list of stories_sales_kits.

  ## Examples

      iex> list_stories_sales_kits()
      [%StorySalesKit{}, ...]

  """
  def list_stories_sales_kits do
    Repo.all(StorySalesKit)
  end

  @doc """
  Gets a single story_sales_kit.

  Raises `Ecto.NoResultsError` if the Story sales kit does not exist.

  ## Examples

      iex> get_story_sales_kit!(123)
      %StorySalesKit{}

      iex> get_story_sales_kit!(456)
      ** (Ecto.NoResultsError)

  """
  def get_story_sales_kit!(id), do: Repo.get!(StorySalesKit, id)

  def get_story_sales_kit_by_uuid!(uuid),
    do: Repo.get_by!(StorySalesKit, uuid: uuid)

  @doc """
  Creates a story_sales_kit.

  ## Examples

      iex> create_story_sales_kit(%{field: value})
      {:ok, %StorySalesKit{}}

      iex> create_story_sales_kit(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story_sales_kit(attrs \\ %{}) do
    %StorySalesKit{}
    |> StorySalesKit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a story_sales_kit.

  ## Examples

      iex> update_story_sales_kit(story_sales_kit, %{field: new_value})
      {:ok, %StorySalesKit{}}

      iex> update_story_sales_kit(story_sales_kit, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_story_sales_kit(%StorySalesKit{} = story_sales_kit, attrs) do
    story_sales_kit
    |> StorySalesKit.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a StorySalesKit.

  ## Examples

      iex> delete_story_sales_kit(story_sales_kit)
      {:ok, %StorySalesKit{}}

      iex> delete_story_sales_kit(story_sales_kit)
      {:error, %Ecto.Changeset{}}

  """
  def delete_story_sales_kit(%StorySalesKit{} = story_sales_kit) do
    Repo.delete(story_sales_kit)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking story_sales_kit changes.

  ## Examples

      iex> change_story_sales_kit(story_sales_kit)
      %Ecto.Changeset{source: %StorySalesKit{}}

  """
  def change_story_sales_kit(%StorySalesKit{} = story_sales_kit) do
    StorySalesKit.changeset(story_sales_kit, %{})
  end

  @doc """
  1. Fetches the file from s3 first
  2. Stores that file on the server
  3. Remember to delete the file stored on server(done via worker itself)
  """
  def get_sales_kit_pdf_file_path(story_sales_kit) do
    path = story_sales_kit |> StorySalesKit.fetch_s3_path() |> URI.decode()
    files_bucket = ApplicationHelper.get_files_bucket()
    {:ok, body} = S3Helper.get_file(files_bucket, path)
    random_suffix = SecureRandom.urlsafe_base64(8)

    file_path = "#{File.cwd!()}/sales_kit_#{story_sales_kit.uuid}_#{random_suffix}.pdf"

    File.write(file_path, body)
    file_path
  end

  @doc """
  1. Read the contents of file from the given path
  2. upload the file content with the newly generated path key
  3. Return that s3 path
  """
  def upload_sales_kit(file_path, sales_kit_uuid, user_uuid \\ "") do
    file = file_path |> File.read!()
    files_bucket = ApplicationHelper.get_files_bucket()
    random_suffix = SecureRandom.urlsafe_base64(8)

    s3_path = "sales_kit/#{sales_kit_uuid}/personalised/#{user_uuid}/#{random_suffix}.pdf"

    S3Helper.put_file(files_bucket, s3_path, file)
    s3_path
  end

  alias BnApis.Stories.AttachmentType

  @doc """
  Returns the list of stories_attachment_types.

  ## Examples

      iex> list_stories_attachment_types()
      [%AttachmentType{}, ...]

  """
  def list_stories_attachment_types do
    Repo.all(AttachmentType)
  end

  @doc """
  Gets a single attachment_type.

  Raises `Ecto.NoResultsError` if the Attachment type does not exist.

  ## Examples

      iex> get_attachment_type!(123)
      %AttachmentType{}

      iex> get_attachment_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_attachment_type!(id), do: Repo.get!(AttachmentType, id)

  @doc """
  Creates a attachment_type.

  ## Examples

      iex> create_attachment_type(%{field: value})
      {:ok, %AttachmentType{}}

      iex> create_attachment_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_attachment_type(attrs \\ %{}) do
    %AttachmentType{}
    |> AttachmentType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a attachment_type.

  ## Examples

      iex> update_attachment_type(attachment_type, %{field: new_value})
      {:ok, %AttachmentType{}}

      iex> update_attachment_type(attachment_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_attachment_type(%AttachmentType{} = attachment_type, attrs) do
    attachment_type
    |> AttachmentType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AttachmentType.

  ## Examples

      iex> delete_attachment_type(attachment_type)
      {:ok, %AttachmentType{}}

      iex> delete_attachment_type(attachment_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_attachment_type(%AttachmentType{} = attachment_type) do
    Repo.delete(attachment_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking attachment_type changes.

  ## Examples

      iex> change_attachment_type(attachment_type)
      %Ecto.Changeset{source: %AttachmentType{}}

  """
  def change_attachment_type(%AttachmentType{} = attachment_type) do
    AttachmentType.changeset(attachment_type, %{})
  end

  alias BnApis.Stories.UserSeen

  @doc """
  Returns the list of stories_user_seens.

  ## Examples

      iex> list_stories_user_seens()
      [%UserSeen{}, ...]

  """
  def list_stories_user_seens do
    Repo.all(UserSeen)
  end

  @doc """
  Gets a single user_seen.

  Raises `Ecto.NoResultsError` if the User seen does not exist.

  ## Examples

      iex> get_user_seen!(123)
      %UserSeen{}

      iex> get_user_seen!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_seen!(id), do: Repo.get!(UserSeen, id)

  @doc """
  Creates a user_seen.

  ## Examples

      iex> create_user_seen(%{field: value})
      {:ok, %UserSeen{}}

      iex> create_user_seen(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_seen(attrs \\ %{}) do
    %UserSeen{}
    |> UserSeen.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_seen.

  ## Examples

      iex> update_user_seen(user_seen, %{field: new_value})
      {:ok, %UserSeen{}}

      iex> update_user_seen(user_seen, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_seen(%UserSeen{} = user_seen, attrs) do
    user_seen
    |> UserSeen.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserSeen.

  ## Examples

      iex> delete_user_seen(user_seen)
      {:ok, %UserSeen{}}

      iex> delete_user_seen(user_seen)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_seen(%UserSeen{} = user_seen) do
    Repo.delete(user_seen)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_seen changes.

  ## Examples

      iex> change_user_seen(user_seen)
      %Ecto.Changeset{source: %UserSeen{}}

  """
  def change_user_seen(%UserSeen{} = user_seen) do
    UserSeen.changeset(user_seen, %{})
  end

  alias BnApis.Stories.UserFavourite

  @doc """
  Returns the list of stories_user_favourites.

  ## Examples

      iex> list_stories_user_favourites()
      [%UserFavourite{}, ...]

  """
  def list_stories_user_favourites do
    Repo.all(UserFavourite)
  end

  @doc """
  Gets a single user_favourite.

  Raises `Ecto.NoResultsError` if the User favourite does not exist.

  ## Examples

      iex> get_user_favourite!(123)
      %UserFavourite{}

      iex> get_user_favourite!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_favourite!(id), do: Repo.get!(UserFavourite, id)

  @doc """
  Creates a user_favourite.

  ## Examples

      iex> create_user_favourite(%{field: value})
      {:ok, %UserFavourite{}}

      iex> create_user_favourite(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_favourite(attrs \\ %{}) do
    %UserFavourite{}
    |> UserFavourite.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_favourite.

  ## Examples

      iex> update_user_favourite(user_favourite, %{field: new_value})
      {:ok, %UserFavourite{}}

      iex> update_user_favourite(user_favourite, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_favourite(%UserFavourite{} = user_favourite, attrs) do
    user_favourite
    |> UserFavourite.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserFavourite.

  ## Examples

      iex> delete_user_favourite(user_favourite)
      {:ok, %UserFavourite{}}

      iex> delete_user_favourite(user_favourite)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_favourite(%UserFavourite{} = user_favourite) do
    Repo.delete(user_favourite)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_favourite changes.

  ## Examples

      iex> change_user_favourite(user_favourite)
      %Ecto.Changeset{source: %UserFavourite{}}

  """
  def change_user_favourite(%UserFavourite{} = user_favourite) do
    UserFavourite.changeset(user_favourite, %{})
  end

  alias BnApis.Stories.StoryCallLog

  @doc """
  Gets a single story call log.

  Raises `Ecto.NoResultsError` if the Story Call Log does not exist.

  ## Examples

      iex> get_story_call_log!(123)
      %StoryCallLog{}

      iex> get_story_call_log_from_uuid!(456)
      ** (Ecto.NoResultsError)

  """
  def get_story_call_log!(id), do: Repo.get!(StoryCallLog, id)

  def get_story_call_log_from_uuid!(uuid),
    do: Repo.get_by!(StoryCallLog, uuid: uuid)

  @doc """
  Creates a story call log.

  ## Examples

      iex> create_story_call_log(%{field: value})
      {:ok, %StoryCallLog{}}

      iex> create_story_call_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_story_call_log(attrs \\ %{}) do
    %StoryCallLog{}
    |> StoryCallLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a story call log.

  ## Examples

      iex> update_story_call_log(story_call_log, %{field: new_value})
      {:ok, %StoryCallLog{}}

      iex> update_story_call_log(story_call_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_story_call_log(%StoryCallLog{} = story_call_log, attrs) do
    story_call_log
    |> StoryCallLog.changeset(attrs)
    |> Repo.update()
  end

  def calculate_avg_cost_per_sq_ft(nil), do: nil
  def calculate_avg_cost_per_sq_ft([]), do: nil

  def calculate_avg_cost_per_sq_ft(project_configs) do
    total_starting_price =
      project_configs
      |> Enum.reduce(0, fn project_config, acc ->
        starting_price = if not is_nil(project_config) and project_config.active, do: project_config.starting_price, else: 0
        starting_price + acc
      end)

    total_carpet_area =
      project_configs
      |> Enum.reduce(0, fn project_config, acc ->
        carpet_area = if not is_nil(project_config) and project_config.active, do: project_config.carpet_area, else: 0
        carpet_area + acc
      end)

    if total_carpet_area != 0, do: total_starting_price / total_carpet_area, else: 0
  end

  def create_map_for_story_sales_kits(nil), do: nil

  def create_map_for_story_sales_kits(story_sales_kits) do
    sales_kits_with_youtube_urls =
      story_sales_kits
      |> Enum.filter(fn sales_kit ->
        sales_kit.attachment_type_id == AttachmentType.youtube_url().id
      end)

    sales_kit_with_youtube_urls_map =
      sales_kits_with_youtube_urls
      |> Enum.map(fn sales_kit ->
        create_map_for_sales_kit_with_youtube_url(sales_kit)
      end)

    sales_kits_with_documents =
      story_sales_kits
      |> Enum.filter(fn sales_kit ->
        sales_kit.attachment_type_id != AttachmentType.youtube_url().id
      end)

    sales_kits_with_documents_map =
      sales_kits_with_documents
      |> Enum.map(fn sales_kit ->
        create_map_for_sales_kit_with_documents(sales_kit)
      end)

    %{
      documents: sales_kits_with_documents_map,
      youtube_urls: sales_kit_with_youtube_urls_map
    }
  end

  defp create_map_for_sales_kit_with_youtube_url(sales_kit) do
    %{
      uuid: sales_kit.uuid,
      name: sales_kit.name,
      thumbnail: create_thumbnail_url(String.trim(sales_kit.youtube_url)),
      type: sales_kit.attachment_type_id,
      attachment_type_id: sales_kit.attachment_type_id,
      youtube_url: sales_kit.youtube_url,
      active: sales_kit.active
    }
  end

  defp create_map_for_sales_kit_with_documents(sales_kit) do
    size_in_mb =
      if is_nil(sales_kit.size_in_mb),
        do: sales_kit.size_in_mb,
        else: sales_kit.size_in_mb |> Decimal.to_float()

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

  defp create_thumbnail_url(nil), do: nil
  defp create_thumbnail_url(""), do: nil

  defp create_thumbnail_url(url) do
    youtube_identifier = String.splitter(url, "/") |> Enum.take(-1) |> Enum.at(-1)

    youtube_identifier =
      if String.contains?(youtube_identifier, "watch?v="),
        do: String.slice(youtube_identifier, 8..-1),
        else: youtube_identifier

    @youtube_thumbnail_url <> youtube_identifier <> @youtube_thumbnail_default_img
  end

  defp filter_youtube_urls(story_sales_kits) do
    story_sales_kits
    |> Enum.map(fn sales_kit ->
      Map.delete(sales_kit, :youtube_url)
    end)
  end

  defp add_operating_city_filter(nil, stories), do: stories

  defp add_operating_city_filter(operating_city_id, stories) do
    operating_city_id =
      if is_binary(operating_city_id),
        do: String.to_integer(operating_city_id),
        else: operating_city_id

    stories |> where([s], ^operating_city_id in s.operating_cities)
  end

  def get_project_filters_metadata(logged_in_user) do
    city_id = logged_in_user[:operating_city]
    filters_list = create_base_filters_list()

    filters_list =
      if should_activate_filter_tag?(%{"sv_reward" => "true"}, city_id) do
        [
          %{"view_order_id" => 2, "label" => "Site Visit Rewards", "query_parameter" => "sv_reward=true", "is_location_permission_required" => false, "pre_selected" => false}
          | filters_list
        ]
      else
        filters_list
      end

    filters_list =
      if should_activate_filter_tag?(%{"br_flag" => "true"}, city_id) do
        [
          %{"view_order_id" => 4, "label" => "Booking Rewards", "query_parameter" => "br_flag=true", "is_location_permission_required" => false, "pre_selected" => false}
          | filters_list
        ]
      else
        filters_list
      end

    Enum.sort_by(filters_list, & &1["view_order_id"])
  end

  defp create_base_filters_list() do
    [
      %{
        "view_order_id" => 1,
        "label" => "Near me",
        "query_parameter" => "lat=lat_value&long=long_value",
        "is_location_permission_required" => true,
        "pre_selected" => false
      },
      %{
        "view_order_id" => 3,
        "label" => "Recently Added",
        "query_parameter" => "added_recent=15",
        "is_location_permission_required" => false,
        "pre_selected" => false
      }
    ]
  end

  defp should_activate_filter_tag?(filter, operating_city) do
    result =
      Story.filter_story_query(filter, operating_city, [])
      |> limit(1)
      |> Repo.all()

    result != []
  end
end
