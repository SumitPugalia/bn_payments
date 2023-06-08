defmodule BnApis.Stories.Story do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  use Appsignal.Instrumentation.Decorators

  alias BnApis.Repo
  alias BnApis.Developers.Developer
  alias BnApis.Places.Polygon
  alias BnApis.Rewards.StoryTransaction
  alias BnApis.Rewards.Payout
  alias BnApis.Posts.ProjectType
  alias BnApis.Rewards.StoryTierPlanMapping
  alias BnApis.Stories.LegalEntity
  alias BnApis.Stories.StoryLegalEntityMapping
  alias BnApis.Stories.Schema.MandateCompany
  alias BnApis.Posts.ConfigurationType

  alias BnApis.Stories.{
    Story,
    StorySection,
    StorySalesKit,
    UserFavourite,
    StoryDeveloperPocMapping,
    StoryProjectConfig
  }

  alias BnApis.Rewards.StoryTier
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Accounts.{EmployeeCredential, DeveloperPocCredential}
  alias BnApisWeb.Helpers.BuildingHelper
  alias BnApis.Stories.Schema.PriorityStory
  alias BnApis.Helpers.Utils

  @story_per_page 10

  schema "stories" do
    field(:archived, :boolean, default: false)
    field(:image_url, :string)
    field(:thumbnail_image_url, :string)
    field(:new_story_thumbnail_image_url, :string)
    field(:project_logo_url, :string)
    field(:interval, :integer)
    field(:onboarded_date, :naive_datetime)
    field(:name, :string)
    field(:phone_number, :string)
    field(:contact_person_name, :string)
    field(:published, :boolean, default: false)
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:operating_cities, {:array, :integer}, default: [])
    field(:configuration_type_ids, {:array, :integer}, default: [])
    field(:min_carpet_area, :integer)
    field(:max_carpet_area, :integer)
    field(:possession_by, :naive_datetime)
    field(:is_rewards_enabled, :boolean, default: false)
    field(:is_manually_deacticated_for_rewards, :boolean, default: false)
    field(:is_cab_booking_enabled, :boolean, default: false)
    field(:is_advance_brokerage_enabled, :boolean, default: false)
    field(:total_rewards_amount, :integer, default: 0)
    field(:latitude, :string)
    field(:longitude, :string)
    field(:google_maps_url, :string)
    field(:marketing_kit_url, :string)
    field(:is_invoicing_enabled, :boolean, default: false)
    field(:is_enabled_for_commercial, :boolean, default: false)
    field(:is_booking_reward_enabled, :boolean, default: false)
    field(:blocked_for_reward_approval, :boolean, default: false)
    # Types -> "regular" and "advanced"
    field(:invoicing_type, :string)
    field(:brokerage_proof_url, :string)
    field(:advanced_brokerage_percent, :integer)
    field(:rera_ids, {:array, :string})
    field(:disabled_rewards_reason, :string)
    field(:gate_pass, :string)
    field(:distance, :float, virtual: true)
    field(:has_mandate_company, :boolean, default: false)

    belongs_to(:rewards_bn_poc, EmployeeCredential,
      foreign_key: :rewards_bn_poc_id,
      references: :id
    )

    belongs_to(:polygon, Polygon)

    belongs_to :default_story_tier, StoryTier

    belongs_to :story_tier, StoryTier

    belongs_to :project_type, ProjectType

    belongs_to(:developer, Developer)

    belongs_to(:mandate_company, MandateCompany)

    belongs_to(:sv_business_development_manager, EmployeeCredential,
      foreign_key: :sv_business_development_manager_id,
      references: :id
    )

    belongs_to(:sv_implementation_manager, EmployeeCredential,
      foreign_key: :sv_implementation_manager_id,
      references: :id
    )

    belongs_to(:sv_market_head, EmployeeCredential, foreign_key: :sv_market_head_id, references: :id)
    belongs_to(:sv_cluster_head, EmployeeCredential, foreign_key: :sv_cluster_head_id, references: :id)
    belongs_to(:sv_account_manager, EmployeeCredential, foreign_key: :sv_account_manager_id, references: :id)

    has_many(:user_favourites, UserFavourite)

    has_many(:story_sections, StorySection,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:story_sales_kits, StorySalesKit,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:story_developer_poc_mappings, StoryDeveloperPocMapping,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:story_tier_plan_mapping, StoryTierPlanMapping,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:story_transactions, StoryTransaction,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:payouts, Payout,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:story_project_configs, StoryProjectConfig,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    has_many(:priority_stories, PriorityStory,
      foreign_key: :story_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    many_to_many(:legal_entities, LegalEntity, join_through: StoryLegalEntityMapping, on_replace: :delete)

    timestamps()
  end

  @fields [
    :name,
    :interval,
    :image_url,
    :developer_id,
    :phone_number,
    :contact_person_name,
    :published,
    :operating_cities,
    :min_carpet_area,
    :max_carpet_area,
    :possession_by,
    :configuration_type_ids,
    :thumbnail_image_url,
    :project_logo_url,
    :new_story_thumbnail_image_url,
    :is_rewards_enabled,
    :is_cab_booking_enabled,
    :total_rewards_amount,
    :latitude,
    :longitude,
    :google_maps_url,
    :project_type_id,
    :marketing_kit_url,
    :rewards_bn_poc_id,
    :sv_business_development_manager_id,
    :sv_implementation_manager_id,
    :sv_market_head_id,
    :sv_cluster_head_id,
    :sv_account_manager_id,
    :polygon_id,
    :onboarded_date,
    :story_tier_id,
    :is_advance_brokerage_enabled,
    :is_invoicing_enabled,
    :is_booking_reward_enabled,
    :invoicing_type,
    :brokerage_proof_url,
    :advanced_brokerage_percent,
    :rera_ids,
    :default_story_tier_id,
    :is_manually_deacticated_for_rewards,
    :blocked_for_reward_approval,
    :disabled_rewards_reason,
    :is_enabled_for_commercial,
    :has_mandate_company,
    :mandate_company_id
  ]

  @required_fields [:name, :interval, :developer_id]
  @doc false
  def changeset(story, attrs \\ %{}) do
    story
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_invoicing_type()
    |> validate_has_mandate_company()
    |> cast_assoc(:story_sections,
      with: &StorySection.changeset/2,
      required: true
    )
    |> cast_assoc(:story_sales_kits,
      with: &StorySalesKit.changeset/2,
      required: true
    )
    |> cast_assoc(:story_project_configs,
      with: &StoryProjectConfig.changeset/2
    )
    |> foreign_key_constraint(:developer_id)
    |> foreign_key_constraint(:story_tier_id)
    |> foreign_key_constraint(:mandate_company_id)
  end

  def get_is_booking_reward_enabled_on_app(story) do
    legal_entities = StoryLegalEntityMapping.get_legal_entities_for_story(story.id)
    get_is_booking_reward_enabled_on_app(story, legal_entities)
  end

  def get_is_booking_reward_enabled_on_app(story, legal_entities) do
    story.is_booking_reward_enabled and not is_nil(story.rera_ids) and length(story.rera_ids) > 0 and
      length(legal_entities) > 0
  end

  defp validate_invoicing_type(changeset) do
    invoicing_type = get_field(changeset, :invoicing_type)

    if Enum.member?([nil, "regular", "advanced"], invoicing_type) do
      changeset
    else
      add_error(changeset, :invoicing_type, "Invoicing type should be one of: regular or advanced")
    end
  end

  def publish_changeset(story) do
    story |> change(published: true)
  end

  def story_section_query(story_uuid, section_uuid) do
    StorySection
    |> where(uuid: ^section_uuid)
    |> join(:inner, [sec], s in assoc(sec, :story), on: s.uuid == ^story_uuid)
  end

  def user_favourite_query(credential_id, story_id) do
    UserFavourite
    |> where(credential_id: ^credential_id)
    |> where(story_id: ^story_id)
  end

  def per_page do
    @story_per_page
  end

  def story_sections_query do
    StorySection
    |> preload([:user_seens])
    |> where([ss], ss.active == true)
    |> order_by([ss], asc: ss.order)
  end

  def story_sales_kits_query do
    StorySalesKit |> where([sk], sk.active == true)
  end

  def story_project_configs_query do
    StoryProjectConfig |> where([spc], spc.active == true)
  end

  @doc """
  All Stories (except archived).
  """
  def all_stories_query(user_operating_city \\ nil) do
    city_filter = is_nil(user_operating_city)
    # FIXME: Don't load all user_favourites and user_seens
    Story
    |> where([s], s.archived == false and s.published == true)
    |> where([s], ^city_filter or ^user_operating_city in s.operating_cities)
    |> preload([
      :developer,
      :user_favourites,
      story_sales_kits: ^story_sales_kits_query(),
      story_project_configs: ^story_project_configs_query(),
      story_sections: ^story_sections_query()
    ])
    |> order_by(desc: :inserted_at)
  end

  @doc """
  Includes archived stories
  """
  def all_favourite_query(cred_id) do
    Story
    |> where(published: true)
    |> join(
      :inner,
      [s],
      uf in assoc(s, :user_favourites),
      on: uf.credential_id == ^cred_id and not is_nil(uf.timestamp)
    )
    |> preload([
      :developer,
      :story_sales_kits,
      :story_project_configs,
      :user_favourites,
      story_sections: ^story_sections_query()
    ])
    |> order_by([story, uf], desc: uf.timestamp)
  end

  def add_limit(query, page) do
    query
    |> limit(^@story_per_page)
    |> offset(^((page - 1) * @story_per_page))
  end

  def get_count(query) do
    query
    |> BnApis.Repo.aggregate(:count, :id)
  end

  def get_group_count(query) do
    query
    |> select([s], count(s.id))
    |> Repo.all()
    |> length()
  end

  def search_story_query(search_text, user_operating_city, exclude_story_uuids, flags) do
    modified_search_text = "%" <> search_text <> "%"
    story_project_configs_query = from project_config in StoryProjectConfig, where: project_config.active == true, distinct: project_config.configuration_type_id

    query =
      Story
      |> preload([
        :developer,
        :polygon,
        :story_developer_poc_mappings,
        story_developer_poc_mappings: [:developer_poc_credential],
        story_project_configs: [:configuration_type],
        story_project_configs: ^story_project_configs_query
      ])
      |> join(:inner, [s], d in Developer, on: s.developer_id == d.id)
      |> where([s], s.archived == false and s.published == true)

    query =
      if not is_nil(exclude_story_uuids) do
        query |> where([s], s.uuid not in ^exclude_story_uuids)
      else
        query
      end

    query =
      if not is_nil(search_text) and search_text != "" do
        query |> where([s, d], ilike(s.name, ^modified_search_text) or ilike(d.name, ^modified_search_text))
      else
        query
      end

    query =
      if not is_nil(flags[:is_rewards_enabled]) and flags[:is_rewards_enabled] == true,
        do: query |> where([s], s.is_rewards_enabled == ^flags[:is_rewards_enabled]),
        else: query

    query =
      if not is_nil(flags[:is_cab_booking_enabled]) and flags[:is_cab_booking_enabled] == true,
        do: query |> where([s], s.is_cab_booking_enabled == ^flags[:is_cab_booking_enabled]),
        else: query

    query
    |> order_by([s], desc: ^user_operating_city in s.operating_cities, asc: s.name)
    |> limit(50)
  end

  def search_story_legal_entity_query(
        search_text,
        exclude_story_uuids,
        operating_city_id,
        limit,
        offset,
        br_flag,
        inv_flag
      ) do
    modified_search_text = "%" <> search_text <> "%"

    base_query =
      Story
      |> join(:inner, [s], mapping in StoryLegalEntityMapping, on: s.id == mapping.story_id)
      |> join(:inner, [s, mapping], le in LegalEntity, on: mapping.legal_entity_id == le.id)
      |> where([s, mapping, le], mapping.active == true and fragment("? != '{}'", s.rera_ids))
      |> distinct([s], s.id)
      |> maybe_exclude_story_uuids(exclude_story_uuids)

    search_query =
      if is_nil(search_text) or search_text == "" do
        where(base_query, [s], ^operating_city_id in s.operating_cities)
      else
        where(
          base_query,
          [s, _map, le],
          fragment("LOWER(?) LIKE LOWER(?)", s.name, ^modified_search_text) or
            fragment("LOWER(?) LIKE LOWER(?)", le.legal_entity_name, ^modified_search_text)
        )
      end

    search_query =
      if is_nil(br_flag) do
        search_query
      else
        search_query |> where([s], s.is_booking_reward_enabled == ^br_flag)
      end

    search_query =
      if is_nil(inv_flag) do
        search_query
      else
        search_query |> where([s], s.is_invoicing_enabled == ^inv_flag)
      end

    search_query
    |> preload([:developer, :story_project_configs, :polygon])
    |> order_by([s], asc: s.name, desc: ^operating_city_id in s.operating_cities)
    |> limit(^limit)
    |> offset(^offset)
  end

  def admin_search_story_query(search_text, exclude_story_uuids, city_id \\ nil, is_cab_booking_enabled \\ nil) do
    stories =
      Story
      |> where([s], s.archived == false and s.published == true)
      |> where([s], s.uuid not in ^exclude_story_uuids)

    stories =
      if not is_nil(search_text) do
        modified_search_text = "%" <> search_text <> "%"
        stories |> where([s], ilike(s.name, ^modified_search_text))
      else
        stories
      end

    stories =
      if not is_nil(city_id) do
        city_id = if is_binary(city_id), do: String.to_integer(city_id), else: city_id
        stories |> where([s], ^city_id in s.operating_cities)
      else
        stories
      end

    stories =
      if not is_nil(is_cab_booking_enabled) do
        stories
        |> where([s], s.is_cab_booking_enabled == ^is_cab_booking_enabled)
      else
        stories
      end

    stories =
      if not is_nil(search_text) and search_text != "" do
        stories
        |> order_by([s], fragment("lower(?) <-> ?", s.name, ^search_text))
      else
        stories
      end

    stories
    |> limit(^@story_per_page)
    |> select([s], %{
      uuid: s.uuid,
      name: s.name,
      id: s.id,
      sub_title: s.name,
      is_cab_booking_enabled: s.is_cab_booking_enabled
    })
  end

  def filter_story_query(filters, user_operating_city, exclude_story_uuids) do
    city = if not is_nil(filters["city_id"]), do: filters["city_id"], else: user_operating_city

    query =
      Story
      |> where(^filter_story_where_params(filters))
      |> join(:left, [s], pc in StoryProjectConfig, on: pc.story_id == s.id and pc.active == true)
      |> join(:left, [s, pc], ps in PriorityStory, on: ps.story_id == s.id and ps.active == true and ps.city_id == ^city)
      |> where([s], ^city in s.operating_cities and s.archived == false and s.published == true)
      |> filter_by_booking_reward(filters)
      |> filter_by_lat_long(filters)

    query =
      if not is_nil(exclude_story_uuids) do
        query |> where([s], s.uuid not in ^exclude_story_uuids)
      else
        query
      end

    query =
      if not is_nil(filters["min_carpet_area"]),
        do: query |> where([s], s.min_carpet_area >= ^filters["min_carpet_area"]),
        else: query

    query =
      if not is_nil(filters["max_carpet_area"]),
        do: query |> where([s], s.max_carpet_area <= ^filters["max_carpet_area"]),
        else: query

    query =
      if not is_nil(filters["possession_by"]) do
        {:ok, possession_by_datetime} = DateTime.from_unix(filters["possession_by"])
        query |> where([s], s.possession_by <= ^possession_by_datetime)
      else
        query
      end

    query =
      if not is_nil(filters["project_type_id"]),
        do: query |> where([s], s.project_type_id == ^filters["project_type_id"]),
        else: query

    query =
      if not is_nil(filters["configuration_type_ids"]) and length(filters["configuration_type_ids"]) > 0,
        do:
          query
          |> where(
            [s, pc],
            fragment(
              "?::int[] && ?",
              s.configuration_type_ids,
              ^filters["configuration_type_ids"]
            ) or pc.configuration_type_id in ^filters["configuration_type_ids"]
          ),
        else: query

    query =
      if not is_nil(filters["min_price"]),
        do: query |> where([s, pc], pc.starting_price >= ^filters["min_price"]),
        else: query

    query =
      if not is_nil(filters["max_price"]),
        do: query |> where([s, pc], pc.starting_price <= ^filters["max_price"]),
        else: query

    query =
      if not is_nil(filters["polygon_ids"]) and length(filters["polygon_ids"]) > 0 do
        query
        |> join(:left, [s, pc, ps, mapping, le], p in Polygon, on: p.id == s.polygon_id)
        |> where([s, ..., p], p.id in ^filters["polygon_ids"])
      else
        query
      end

    query
    |> group_by([s, pc, ps], [s.id, ps.priority])
    |> order_by_param(filters)
  end

  def filter_story_query_count(
        filters,
        user_operating_city,
        exclude_story_uuids
      ) do
    filter_story_query(filters, user_operating_city, exclude_story_uuids)
    |> Story.get_group_count()
  end

  def get_last_story(user_operating_city) do
    Story
    |> where([s], ^user_operating_city in s.operating_cities)
    |> where([s], s.published == true and s.archived == false)
    |> order_by([s], desc: s.updated_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_developer_pocs(story) do
    story.story_developer_poc_mappings
    |> Enum.filter(fn sdm -> sdm.active == true end)
    |> Enum.map(& &1.developer_poc_credential)
  end

  @decorate transaction_event()
  def get_story_balances(story) do
    story =
      story
      |> BnApis.Repo.preload([
        :story_transactions,
        :story_tier,
        :default_story_tier
      ])

    story_tier_map =
      StoryTier
      |> Repo.all()
      |> Enum.reduce(%{}, fn st, acc ->
        Map.put(acc, st.id, st.amount)
      end)

    transactions = story.story_transactions |> Enum.filter(fn st -> st.active end)

    total_credit_amount = Kernel.round(Enum.sum(Enum.map(transactions, fn st -> st.amount end)))

    payout_rewards_for_approval_map =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
      |> where([rl, rls], rl.story_id == ^story.id and rls.status_id in ^[4, 5])
      |> where([rl, rls], rl.is_conflict != true)
      |> Repo.all()
      |> Enum.reduce(%{}, fn rl, acc ->
        amount = if not is_nil(rl.story_tier_id), do: story_tier_map[rl.story_tier_id], else: 300
        Map.put(acc, rl.id, amount)
      end)

    pending_rewards_for_approval_map =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
      |> where([rl, rls], rl.story_id == ^story.id and rls.status_id == ^1)
      |> where([rl, rls], rl.is_conflict != true)
      |> Repo.all()
      |> Enum.reduce(%{}, fn rl, acc ->
        amount = if not is_nil(rl.story_tier_id), do: story_tier_map[rl.story_tier_id], else: 300
        Map.put(acc, rl.id, amount)
      end)

    approved_rewards_for_approval_map =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
      |> where([rl, rls], rl.story_id == ^story.id and rls.status_id == ^3)
      |> where([rl, rls], rl.is_conflict != true)
      |> Repo.all()
      |> Enum.reduce(%{}, fn rl, acc ->
        amount = if not is_nil(rl.story_tier_id), do: story_tier_map[rl.story_tier_id], else: 300
        Map.put(acc, rl.id, amount)
      end)

    total_approved_amount =
      Kernel.round(
        Enum.reduce(approved_rewards_for_approval_map, 0, fn {_id, amount}, acc ->
          acc + amount
        end)
      )

    total_pending_amount =
      Kernel.round(
        Enum.reduce(pending_rewards_for_approval_map, 0, fn {_id, amount}, acc ->
          acc + amount
        end)
      )

    total_payment_done =
      Kernel.round(
        Enum.reduce(payout_rewards_for_approval_map, 0, fn {_id, amount}, acc ->
          acc + amount
        end)
      )

    %{
      total_credits_amount: total_credit_amount,
      total_debits_amount: total_payment_done,
      total_approved_amount: total_approved_amount,
      total_pending_amount: total_pending_amount,
      story_tier_amount: get_effective_story_tier_amount(story)
    }
  end

  def get_story_details_for_rewards(story, fetch_developer_pocs \\ false) do
    locality =
      case story.polygon do
        %{name: name} ->
          name

        _ ->
          "Powai"
      end

    response = %{
      uuid: story.uuid,
      name: story.name,
      project_logo_url: story.project_logo_url,
      locality: locality
    }

    if fetch_developer_pocs do
      developer_pocs =
        get_developer_pocs(story)
        |> DeveloperPocCredential.to_map()

      Map.put(response, :developer_pocs, developer_pocs)
    else
      response
    end
  end

  def rewards_enabled_query(user_operating_city \\ nil) do
    city_filter = is_nil(user_operating_city)

    Story
    |> where([s], s.archived == false and s.published == true)
    |> where([s], ^city_filter or ^user_operating_city in s.operating_cities)
    |> where([s], s.is_rewards_enabled == true)
    |> preload([:polygon, :story_developer_poc_mappings, story_developer_poc_mappings: [:developer_poc_credential]])
    |> order_by(desc: :inserted_at)
  end

  def stories_by_ids(ids) do
    Story
    |> where([s], s.id in ^ids)
    |> Repo.all()
    |> Repo.preload(:polygon)
  end

  def stories_by_uuids(uuids) do
    Story
    |> where([s], s.uuid in ^uuids)
    |> Repo.all()
  end

  def get_sendbird_payload(story, is_update \\ false) do
    payload = %{
      "nickname" => story.name,
      "profile_url" => story.project_logo_url
    }

    if is_update == false do
      payload
      |> Map.merge(%{
        "user_id" => story.uuid,
        "metadata" => %{
          "phone_number" => story.phone_number
        }
      })
    else
      payload
    end
  end

  def get_sendbird_metadata_payload(story) do
    %{
      "value" => story.phone_number
    }
  end

  def story_changeset_serializer(story_changeset) do
    story_section_changes =
      if Map.has_key?(story_changeset.changes, :story_sections) do
        Enum.map(story_changeset.changes.story_sections, fn x -> x.changes end)
      end

    story_sales_kits_changes =
      if Map.has_key?(story_changeset.changes, :story_sales_kits) do
        Enum.map(story_changeset.changes.story_sales_kits, fn x -> x.changes end)
      end

    story_project_configs_changes =
      if Map.has_key?(story_changeset.changes, :story_project_configs) do
        Enum.map(story_changeset.changes.story_project_configs, fn x -> x.changes end)
      end

    story_changeset.changes
    |> Map.put(:story_sections, story_section_changes)
    |> Map.put(:story_sales_kits, story_sales_kits_changes)
    |> Map.put(:story_project_configs, story_project_configs_changes)
  end

  defp get_effective_story_tier_amount(story) do
    cond do
      not is_nil(story.story_tier_id) -> story.story_tier.amount
      not is_nil(story.default_story_tier_id) -> story.default_story_tier.amount
      true -> 300
    end
  end

  def create_story_map(nil), do: nil

  def create_story_map(story) do
    story = story |> Repo.preload([:developer])

    %{
      "story_name" => story.name,
      "developer_name" => story.developer.name
    }
  end

  defp filter_story_where_params(filter) do
    Enum.reduce(filter, dynamic(true), fn
      {"24h_brokerage", "true"}, dynamic ->
        dynamic([s], ^dynamic and s.is_invoicing_enabled == true and s.invoicing_type == "advanced")

      {"24h_brokerage", "false"}, dynamic ->
        dynamic([s], ^dynamic and s.is_invoicing_enabled == true and s.invoicing_type == "regular")

      {"sv_reward", bool}, dynamic ->
        dynamic([s], ^dynamic and s.is_rewards_enabled == ^String.to_existing_atom(bool))

      {"cabs", bool}, dynamic ->
        dynamic([s], ^dynamic and s.is_cab_booking_enabled == ^String.to_existing_atom(bool))

      {"commercial", "true"}, dynamic ->
        dynamic([s], ^dynamic and ^ConfigurationType.commercial()[:id] in s.configuration_type_ids)

      {"added_recent", offset}, dynamic ->
        date = DateTime.utc_now() |> Timex.beginning_of_day() |> Timex.subtract(Timex.Duration.from_days(String.to_integer(offset)))
        dynamic([s], ^dynamic and s.inserted_at >= ^date)

      _, dynamic ->
        dynamic
    end)
  end

  defp filter_by_booking_reward(query, %{"br_flag" => "true"}) do
    query
    |> join(:inner, [s, pc, ps], mapping in StoryLegalEntityMapping, on: s.id == mapping.story_id)
    |> join(:inner, [s, pc, ps, mapping], le in LegalEntity, on: mapping.legal_entity_id == le.id)
    |> where([s], s.is_booking_reward_enabled == true and fragment("? != '{}'", s.rera_ids))
  end

  defp filter_by_booking_reward(query, _filter), do: query

  def filter_by_lat_long(query, %{"lat" => lat, "long" => long}) do
    {long, lat} = BuildingHelper.process_geo_params(%{"longitude" => long, "latitude" => lat})

    query
    |> where([s], not is_nil(s.longitude) and not is_nil(s.latitude))
    |> select_merge(
      [s],
      %{
        distance:
          fragment(
            "ST_Distance(ST_SetSRID(ST_MakePoint(cast(? as float), cast(? as float)), 4326), ST_SetSRID(ST_MakePoint(?, ?), 4326))::float AS distance",
            s.latitude,
            s.longitude,
            ^lat,
            ^long
          )
      }
    )
    |> order_by({:asc, fragment("distance")})
  end

  def filter_by_lat_long(query, _params), do: query

  defp order_by_param(query, %{"order_by" => "asc"}), do: order_by(query, [s, pc, ps], asc: ps.priority, asc: s.inserted_at)

  defp order_by_param(query, params) do
    if filter_by_gate_pass(params) do
      order_by(query, [s, pc, ps], asc: ps.priority, asc: s.gate_pass, desc: s.inserted_at)
    else
      order_by(query, [s, pc, ps], asc: ps.priority, desc: s.inserted_at)
    end
  end

  defp maybe_exclude_story_uuids(query, nil), do: query
  defp maybe_exclude_story_uuids(query, exclude_story_uuids), do: where(query, [s], s.uuid not in ^exclude_story_uuids)

  defp filter_by_gate_pass(filter) do
    count =
      filter
      |> Map.drop(~w(page p))
      |> Enum.reduce(0, fn
        {_k, v}, count when is_nil(v) or v == [] -> count
        _, count -> count + 1
      end)

    count == 0
  end

  defp validate_has_mandate_company(changeset = %{valid?: true}) do
    has_mandate_company = get_field(changeset, :has_mandate_company) |> Utils.parse_boolean_param()

    if has_mandate_company == true do
      validate_required(changeset, [:mandate_company_id])
    else
      changeset
    end
  end

  defp validate_has_mandate_company(changeset), do: changeset
end
