defmodule BnApis.Posts.RentalMatch do
  use Ecto.Schema
  import Ecto.Changeset

  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Posts
  alias BnApis.Posts.{RentalPropertyPost, RentalClientPost, RentalMatch, PostType, PostSubType, MatchHelper}
  alias BnApis.Posts.{ReportedRentalPropertyPost, ReportedRentalClientPost}
  alias BnApis.Accounts.Credential
  alias BnApis.CallLogs.CallLog
  alias BnApis.Places.Polygon
  alias BnApis.Buildings.Building
  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Organizations.Broker
  alias BnApis.Subscriptions.MatchPlusSubscription

  schema "rental_matches" do
    field(:bachelor_ed, :integer)
    field(:edit_distance, :decimal)
    field(:furnishing_ed, :integer)
    field(:rent_ed, :decimal)
    # field(:rental_client_id, :id)
    # field(:rental_property_id, :id)

    field(:is_relevant, :boolean, default: true)
    field(:feedback_by_id, :id)
    field(:already_contacted, :boolean, default: false)
    field(:already_contacted_by, :integer)
    field(:blocked, :boolean, default: false)
    field(:is_unlocked, :boolean, default: false)

    belongs_to(:rental_client, RentalClientPost)
    belongs_to(:rental_property, RentalPropertyPost)
    belongs_to(:outgoing_call_log, CallLog)
    timestamps()
  end

  @required [:rent_ed, :bachelor_ed, :furnishing_ed, :edit_distance]
  @fields @required ++ []

  # 10% buffer
  @max_rent_buffer 0.2

  @doc false
  def changeset(rental_match, attrs) do
    rental_match
    |> cast(attrs, @fields)
    |> validate_required(@required)
  end

  def mark_irrelevant_changeset(rental_match, feedback_by_user_id) do
    rental_match
    |> change(is_relevant: false)
    |> change(feedback_by_id: feedback_by_user_id)
  end

  def update_match_status(id, change_params) do
    change_params = for {key, val} <- change_params, into: %{}, do: {String.to_atom(key), val}
    rental_match = Repo.get(RentalMatch, id)

    if is_nil(rental_match) do
      {:error, %{errors: "Could not find match"}}
    else
      rental_match |> change(change_params) |> Repo.update()
    end
  end

  def filter_matching_buildings(filters, city_id, building_type_ids, exclude_building_ids \\ []) do
    configuration_type_ids_filter = Map.get(filters, "configuration_type_ids", []) |> length() > 0
    furnishing_type_ids_filter = Map.get(filters, "furnishing_type_ids", []) |> length() > 0
    bachelor_filter = if is_nil(Map.get(filters, "is_bachelor")), do: false, else: true
    rent = filters["max_rent"]

    {rent, rent_filter, rent_lower_range, rent_upper_range} =
      unless is_nil(rent) do
        rent = if rent |> is_binary(), do: String.to_integer(rent), else: rent
        {rent, true, round(rent - @max_rent_buffer * rent), round(rent + @max_rent_buffer * rent)}
      else
        {rent, false, 0, 0}
      end

    building_types = building_type_ids |> Enum.map(&BuildingEnums.get_building_type_from_id(&1))

    RentalPropertyPost
    |> where([rpp], not (^furnishing_type_ids_filter) or rpp.furnishing_type_id in ^Map.get(filters, "furnishing_type_ids", []))
    |> where(
      [rpp],
      not (^configuration_type_ids_filter) or rpp.configuration_type_id in ^Map.get(filters, "configuration_type_ids", [])
    )
    |> where([rpp], not (^bachelor_filter) or rpp.is_bachelor_allowed == ^Map.get(filters, "is_bachelor", false))
    |> where(
      [rpp],
      not (^rent_filter) or
        fragment(
          "? >= ? OR (? BETWEEN ? and ?)",
          ^rent,
          rpp.rent_expected,
          rpp.rent_expected,
          ^rent_lower_range,
          ^rent_upper_range
        )
    )
    |> where([rpp], fragment("? >= timezone('utc', NOW())", rpp.expires_in))
    |> join(:inner, [rpp], building in Building, on: building.id == rpp.building_id)
    |> where([rpp, building], building.type in ^building_types)
    |> join(:inner, [rpp, building], p in Polygon, on: p.id == building.polygon_id)
    |> where(
      [rpp, building, p],
      rpp.archived == false and rpp.building_id not in ^exclude_building_ids and p.city_id == ^city_id
    )
    |> suggestions_rent_select_query()
    |> Repo.all()
  end

  defp suggestions_rent_select_query(query) do
    query
    |> select([rpp, building, _], %{
      building_id: building.id,
      id: building.uuid,
      name: building.name,
      display_address: building.display_address,
      location: building.location
    })
  end

  defp rental_building_config_match_query do
    RentalClientPost
    |> join(
      :inner,
      [rcp],
      rpp in RentalPropertyPost,
      on:
        rpp.building_id in rcp.building_ids and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in) and
          fragment("? >= timezone('utc', NOW())", rcp.expires_in) and
          rpp.archived == false and rcp.archived == false and
          not (not is_nil(rpp.assigned_user_id) and rpp.assigned_user_id == rcp.assigned_user_id)
      # not(rcp.is_bachelor and rpp.is_bachelor_allowed == false)
    )
    |> join(:inner, [rcp, rpp], building in Building, on: building.id == rpp.building_id)
    |> join(:inner, [rcp, rpp, building], p in Polygon, on: p.id == building.polygon_id)
  end

  @doc """
  Provided a `Rental Client Post` id and organization id,
  Searches for all rental property matches
  1. Excludes archived rental property posts
  2. Excludes expired posts
  3. Excludes property post ids if provided
  """
  def rental_property_matches_query(
        client_id,
        exclude_user_ids \\ [],
        exclude_property_post_ids \\ [],
        test_post \\ false
      ) do
    rental_building_config_match_query()
    # User can be inactive as well
    |> join(:left, [rcp, rpp, building, p], cred in Credential, on: rpp.assigned_user_id == cred.id)
    |> join(:inner, [rcp, rpp, building, p, cred], rcp_cred in Credential, on: rcp.assigned_user_id == rcp_cred.id)
    |> join(:inner, [rcp, rpp, building, p, cred, rcp_cred], bro in Broker, on: rcp_cred.broker_id == bro.id)
    |> join(:left, [rcp, rpp, building, p, cred, rcp_cred, bro], mps in MatchPlusSubscription, on: bro.id == mps.broker_id)
    |> where(
      [rcp, rpp, building, p, cred],
      rcp.id == ^client_id and
        rpp.test_post == ^test_post and
        rpp.id not in ^exclude_property_post_ids and
        cred.id not in ^exclude_user_ids and
        (is_nil(cred.active) or cred.active == true)
    )
    |> dynamic_match_query()
    |> rental_select_query()
  end

  @doc """
  Provided a `Rental Property Post` id and organization id,
  Searches for all rental client matches
  1. Excludes archived rental client posts
  2. Excludes expired posts
  3. Excludes client post ids if provided
  """
  def rental_client_matches_query(
        property_id,
        exclude_user_ids \\ [],
        exclude_client_post_ids \\ [],
        test_post \\ false
      ) do
    rental_building_config_match_query()
    |> join(:inner, [rcp, rpp, building, p], cred in Credential, on: rcp.assigned_user_id == cred.id)
    |> join(:inner, [rcp, rpp, building, p, cred], rcp_cred in Credential, on: rcp.assigned_user_id == rcp_cred.id)
    |> join(:inner, [rcp, rpp, building, p, cred, rcp_cred], bro in Broker, on: cred.broker_id == bro.id)
    |> join(:left, [rcp, rpp, building, p, cred, rcp_cred, bro], mps in MatchPlusSubscription, on: bro.id == mps.broker_id)
    |> where(
      [rcp, rpp, building, p, cred],
      rpp.id == ^property_id and
        rcp.test_post == ^test_post and
        rcp.id not in ^exclude_client_post_ids and
        cred.id not in ^exclude_user_ids and
        cred.active == true
    )
    |> dynamic_match_query()
    |> rental_select_query()
  end

  defp dynamic_match_query(query) do
    query
    |> where(
      [rcp, rpp, building, p, cred],
      not fragment("?->'configuration_type_id'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "
        CASE WHEN ? = 1 THEN (?->'configuration_type_id'->'1')
          WHEN ? = 2 THEN (?->'configuration_type_id'->'2')
          WHEN ? = 3 THEN (?->'configuration_type_id'->'3')
          WHEN ? = 4 THEN (?->'configuration_type_id'->'4')
          WHEN ? = 5 THEN (?->'configuration_type_id'->'5')
          WHEN ? = 6 THEN (?->'configuration_type_id'->'6')
          WHEN ? = 7 THEN (?->'configuration_type_id'->'7')
          WHEN ? = 8 THEN (?->'configuration_type_id'->'8')
          ELSE ?->'configuration_type_id'->'9'
        END \\?| ?::text[]",
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          p.rent_match_parameters,
          rcp.configuration_type_ids
        )
    )

    # NOTE: earlier order was - rent_expected, furnishing_type, and then configuration_type
    # |> where([rcp, rpp, building, p, cred], not(fragment("?->'rent_expected'->>'filter' = 'true'", p.rent_match_parameters)) or
    #     fragment("? >= ? OR (? BETWEEN ? * (1 - (?->'rent_expected'->>'min')::float) and ? * (1 + (?->'rent_expected'->>'max')::float))",
    #     rcp.max_rent,
    #     rpp.rent_expected,
    #     rpp.rent_expected,
    #     rcp.max_rent,
    #     p.rent_match_parameters,
    #     rcp.max_rent,
    #     p.rent_match_parameters)
    # )
    # |> where([rcp, rpp, building, p, cred], not(fragment("?->'furnishing_type_id'->>'filter' = 'true'",  p.rent_match_parameters)) or
    #   fragment("
    #     CASE WHEN ? = 1 THEN (?->'furnishing_type_id'->'1')
    #       WHEN ? = 2 THEN (?->'furnishing_type_id'->'2')
    #       ELSE ?->'furnishing_type_id'->'3'
    #     END \\?| ?::text[]",
    #   rpp.furnishing_type_id,
    #   p.rent_match_parameters,
    #   rpp.furnishing_type_id,
    #   p.rent_match_parameters,
    #   p.rent_match_parameters,
    #   rcp.furnishing_type_ids
    #   )
    # )
  end

  defp rental_select_query(query) do
    query
    |> select([rcp, rpp, building, p, cred, rcp_cred, bro, mps], %{
      rental_client_id: rcp.id,
      rental_property_id: rpp.id,
      matching_broker_id: cred.id,
      is_unlocked:
        fragment(
          "
        CASE
          WHEN ? = 1
            THEN true
          ELSE
            false
        END
        ",
          mps.status_id
        ),
      furnishing_ed:
        fragment(
          "
          CASE
            WHEN ? = ANY(?)
              THEN 0
            ELSE
              ABS((SELECT MIN(i) from unnest(?) i) - ?)
          END
          ",
          rpp.furnishing_type_id,
          rcp.furnishing_type_ids,
          rcp.furnishing_type_ids,
          rpp.furnishing_type_id
        ),
      rent_ed:
        fragment(
          "
          CASE
            WHEN ((? - ?) / (? * 1.0)) <= 0
              THEN 0
            ELSE
              ROUND(((? - ?) / (? * 1.0)), 4)
          END
          ",
          rpp.rent_expected,
          rcp.max_rent,
          rcp.max_rent,
          rpp.rent_expected,
          rcp.max_rent,
          rcp.max_rent
        ),
      bachelor_ed:
        fragment(
          "
          CASE
            WHEN ? = false and ? = true
              THEN 1
            ELSE 0
          END
          ",
          rpp.is_bachelor_allowed,
          rcp.is_bachelor
        )
    })
  end

  def mark_matches_against_each_other_as_read(user_id, broker_id, call_log_id) do
    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^user_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^broker_id
    )
    |> update(set: [outgoing_call_log_id: ^call_log_id])
    |> Repo.update_all([])

    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^broker_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^user_id
    )
    |> update(set: [outgoing_call_log_id: ^call_log_id])
    |> Repo.update_all([])
  end

  def mark_matches_against_each_other_as_contacted(user_id, broker_id, already_contacted_by) do
    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^user_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^broker_id
    )
    |> update(set: [already_contacted: true, already_contacted_by: ^already_contacted_by])
    |> Repo.update_all([])

    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^broker_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^user_id
    )
    |> update(set: [already_contacted: true, already_contacted_by: ^already_contacted_by])
    |> Repo.update_all([])
  end

  def mark_matches_against_owner_as_contacted(user_id, post_uuid, already_contacted_by) do
    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^user_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.uuid == ^post_uuid
    )
    |> update(set: [already_contacted: true, already_contacted_by: ^already_contacted_by])
    |> Repo.update_all([])
  end

  def mark_matches_against_each_other_as_blocked(user_id, broker_id) do
    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^user_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^broker_id
    )
    |> update(set: [blocked: true])
    |> Repo.update_all([])

    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^broker_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^user_id
    )
    |> update(set: [blocked: true])
    |> Repo.update_all([])
  end

  def mark_matches_against_each_other_as_irrelevant(user_id, broker_id) do
    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^user_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^broker_id
    )
    |> update(set: [is_relevant: false])
    |> Repo.update_all([])

    RentalMatch
    |> join(
      :inner,
      [rm],
      rcp in RentalClientPost,
      on: rm.rental_client_id == rcp.id and rcp.assigned_user_id == ^broker_id
    )
    |> join(
      :inner,
      [rm, _],
      rpp in RentalPropertyPost,
      on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^user_id
    )
    |> update(set: [is_relevant: false])
    |> Repo.update_all([])
  end

  # ===========  Mark Match as Irrelavant ================

  # ===========  Methods for Rental Post Matches ================

  def rent_client_post_context(user_id, rental_client_id) do
    RentalClientPost
    |> where(id: ^rental_client_id)
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.one()
    |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id)
  end

  def rent_property_post_context(user_id, rental_property_id) do
    RentalPropertyPost
    |> where(id: ^rental_property_id)
    |> preload([:building, :assigned_owner, assigned_user: [:broker, :broker_role, :organization]])
    |> Repo.one()
    |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.property().id)
  end

  def rental_match_base_query() do
    RentalMatch
    |> join(:inner, [rm], rpp in RentalPropertyPost,
      on:
        rm.rental_property_id == rpp.id and
          rpp.archived == false and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
    )
    |> join(:inner, [rm, rpp], rcp in RentalClientPost,
      on:
        rm.rental_client_id == rcp.id and
          rcp.archived == false and
          fragment("? >= timezone('utc', NOW())", rcp.expires_in) and
          ((rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true))
    )
  end

  def rent_client_match_context(user_id, rental_client_id) do
    rm =
      rental_match_base_query()
      |> where([rm, rpp, rcp], rm.rental_client_id == ^rental_client_id and rpp.assigned_user_id == ^user_id)
      |> order_by([rm], desc: rm.inserted_at)
      |> limit(1)
      |> select([rm], rm)
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.one()

    case rm do
      nil ->
        %{}

      rm ->
        rp = rm.rental_client
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)
    end
  end

  def rent_property_match_context(user_id, rental_property_id) do
    rm =
      rental_match_base_query()
      |> where([rm, rpp, rcp], rm.rental_property_id == ^rental_property_id and rcp.assigned_user_id == ^user_id)
      |> order_by([rm], desc: rm.inserted_at)
      |> limit(1)
      |> select([rm], rm)
      |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.one()

    case rm do
      nil ->
        %{}

      rm ->
        rp = rm.rental_property
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)
    end
  end

  def rent_client_post_matches(user_id, rental_client_id, page \\ 1, per_page \\ Posts.broker_per_page()) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_client_id == ^rental_client_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    {total_broker_ids, paginated_broker_ids} = MatchHelper.broker_ids_for_client_query(query, page, per_page)

    matches =
      query
      |> order_by([rm, rpp],
        asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp], rpp.assigned_user_id in ^paginated_broker_ids)
      |> select([rm, rpp], %{
        rm: rm,
        assigned_user_id: rpp.assigned_user_id,
        rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rpp.assigned_user_id, rpp.inserted_at)
      })
      |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(
        # &1.rank <= matches_per_broker
        # &&
        &(!is_nil(&1.rm.rental_property.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_property
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)

        is_read = MatchHelper.rental_property_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.inserted_at, post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)

    total_brokers_count = total_broker_ids |> length
    {matches, total_brokers_count}
  end

  def rent_property_post_matches(user_id, rental_property_id, page \\ 1, per_page \\ Posts.broker_per_page()) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_property_id == ^rental_property_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    {total_broker_ids, paginated_broker_ids} = MatchHelper.broker_ids_for_property_query(query, page, per_page)

    matches =
      query
      |> order_by([rm, rpp, rcp],
        asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp, rcp], rcp.assigned_user_id in ^paginated_broker_ids)
      |> select([rm, rpp, rcp], %{
        rm: rm,
        assigned_user_id: rcp.assigned_user_id,
        rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rcp.assigned_user_id, rcp.inserted_at)
      })
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(
        # &1.rank <= matches_per_broker
        # &&
        &(!is_nil(&1.rm.rental_client.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_client
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)

        is_read = MatchHelper.rental_client_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.inserted_at, post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)

    total_brokers_count = total_broker_ids |> length
    {matches, total_brokers_count}
  end

  def rent_client_post_matches_v1(user_id, rental_client_id, page \\ 1, per_page \\ Posts.post_per_page()) do
    reported_rental_property_ids = ReportedRentalPropertyPost.get_reported_rental_property_ids(user_id)

    query =
      rental_match_base_query()
      |> where(
        [rm, rpp, rcp],
        rm.rental_client_id == ^rental_client_id and
          rm.is_relevant == true and
          rm.blocked == false and
          (is_nil(rpp.uploader_type) or rpp.uploader_type == "broker") and
          rpp.id not in ^reported_rental_property_ids
      )

    total_matches =
      query
      |> order_by([rm, rpp],
        # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at
        # asc: rm.edit_distance
      )
      |> select([rm, rpp], %{
        rm: rm,
        assigned_user_id: rpp.assigned_user_id
      })
      |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()

    total_matches_count = total_matches |> length

    matches =
      total_matches
      |> Enum.filter(
        # &1.rank <= matches_per_broker
        # &&
        &(!is_nil(&1.rm.rental_property.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_property
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)

        is_read = MatchHelper.rental_property_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
      |> Enum.slice(((page - 1) * per_page)..(page * per_page - 1))

    has_more_matches = page < Float.ceil(total_matches_count / per_page)

    {matches, total_matches_count, has_more_matches}
  end

  def rent_property_post_matches_v1(user_id, rental_property_id, page \\ 1, per_page \\ Posts.post_per_page()) do
    reported_rental_client_post_ids = ReportedRentalClientPost.get_reported_rental_client_post_ids(user_id)

    query =
      rental_match_base_query()
      |> where(
        [rm, rpp, rcp],
        rm.rental_property_id == ^rental_property_id and
          rm.is_relevant == true and
          rm.blocked == false and
          rcp.assigned_user_id != ^user_id and
          rcp.id not in ^reported_rental_client_post_ids
      )

    # |> join(:inner, [rm, rpp, rcp], cred in Credential, on: rcp.assigned_user_id == cred.id
    #     and cred.active == true
    #   )

    total_matches =
      query
      |> order_by([rm, rpp, rcp],
        # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at
        # asc: rm.edit_distance
      )
      |> select([rm, rpp, rcp], %{
        rm: rm,
        assigned_user_id: rcp.assigned_user_id
      })
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()

    total_matches_count = total_matches |> length

    matches =
      total_matches
      |> Enum.filter(
        # &1.rank <= matches_per_broker
        # &&
        &(!is_nil(&1.rm.rental_client.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_client
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)

        is_read = MatchHelper.rental_client_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
      |> Enum.slice(((page - 1) * per_page)..(page * per_page - 1))

    has_more_matches = page < Float.ceil(total_matches_count / per_page)

    {matches, total_matches_count, has_more_matches}
  end

  def rent_client_post_matches_v2(user_id, rental_client_id, page \\ 1, per_page \\ Posts.post_per_page()) do
    reported_rental_property_ids = ReportedRentalPropertyPost.get_reported_rental_property_ids(user_id)

    query =
      rental_match_base_query()
      |> where(
        [rm, rpp, rcp],
        rm.rental_client_id == ^rental_client_id and
          rm.is_relevant == true and
          rm.blocked == false and
          not (rpp.uploader_type != "owner" and rpp.id in ^reported_rental_property_ids)
      )

    total_matches =
      query
      |> order_by([rm, rpp],
        # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at
        # asc: rm.edit_distance
      )
      |> select([rm, rpp], %{
        rm: rm,
        assigned_user_id: rpp.assigned_user_id
      })
      |> preload(rental_property: [:building, :assigned_owner, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()

    total_matches_count = total_matches |> length

    matches =
      total_matches
      # |> Enum.filter(&(
      #     # &1.rank <= matches_per_broker
      #     # &&
      #     !is_nil(&1.rm.rental_property.assigned_user)
      #   ))
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_property
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)

        is_read = MatchHelper.rental_property_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
      |> Enum.slice(((page - 1) * per_page)..(page * per_page - 1))

    has_more_matches = page < Float.ceil(total_matches_count / per_page)

    {matches, total_matches_count, has_more_matches}
  end

  def rent_property_post_matches_v2(user_id, rental_property_id, page \\ 1, per_page \\ Posts.post_per_page()) do
    reported_rental_client_post_ids = ReportedRentalClientPost.get_reported_rental_client_post_ids(user_id)

    query =
      rental_match_base_query()
      |> where(
        [rm, rpp, rcp],
        rm.rental_property_id == ^rental_property_id and
          rm.is_relevant == true and
          rm.blocked == false and
          rcp.assigned_user_id != ^user_id and
          rcp.id not in ^reported_rental_client_post_ids
      )

    # |> join(:inner, [rm, rpp, rcp], cred in Credential, on: rcp.assigned_user_id == cred.id
    #     and cred.active == true
    #   )

    total_matches =
      query
      |> order_by([rm, rpp, rcp],
        # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at
        # asc: rm.edit_distance
      )
      |> select([rm, rpp, rcp], %{
        rm: rm,
        assigned_user_id: rcp.assigned_user_id
      })
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [:assigned_owner, assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()

    total_matches_count = total_matches |> length

    matches =
      total_matches
      |> Enum.filter(
        # &1.rank <= matches_per_broker
        # &&
        &(!is_nil(&1.rm.rental_client.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_client
        match = MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)

        is_read = MatchHelper.rental_client_is_read(rp.id, user_id)
        match |> Map.merge(%{read: is_read})
      end)
      # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
      |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
      |> Enum.slice(((page - 1) * per_page)..(page * per_page - 1))

    has_more_matches = page < Float.ceil(total_matches_count / per_page)

    {matches, total_matches_count, has_more_matches}
  end

  @doc """
  `Rent Client Post` Own Matches
  """
  def rent_client_post_own_matches(user_id, rental_client_id) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_client_id == ^rental_client_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    matches =
      query
      |> order_by([rm, rpp],
        desc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp], rpp.assigned_user_id == ^user_id)
      |> select([rm, rpp], %{
        rm: rm,
        assigned_user_id: rpp.assigned_user_id
      })
      |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(&(!is_nil(&1.rm.rental_property.assigned_user)))
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_property
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)
      end)

    matches
  end

  def rent_property_post_own_matches(user_id, rental_property_id) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_property_id == ^rental_property_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    matches =
      query
      |> order_by([rm, rpp, rcp],
        desc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp, rcp], rcp.assigned_user_id == ^user_id)
      |> select([rm, rpp, rcp], %{
        rm: rm,
        assigned_user_id: rcp.assigned_user_id
      })
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(&(!is_nil(&1.rm.rental_client.assigned_user)))
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_client
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)
      end)

    matches
  end

  @doc """
  `Rent Client Post` More Matches for broker
  """
  def rent_client_post_more_matches_for_broker(
        user_id,
        rental_client_id,
        matches_per_broker \\ Posts.matches_per_broker(),
        broker_id
      ) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_client_id == ^rental_client_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    matches =
      query
      |> order_by([rm, rpp],
        asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp], rpp.assigned_user_id == ^broker_id)
      |> select([rm, rpp], %{
        rm: rm,
        assigned_user_id: rpp.assigned_user_id,
        rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rpp.assigned_user_id, rpp.inserted_at)
      })
      |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(
        &(&1.rank > matches_per_broker &&
            !is_nil(&1.rm.rental_property.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_property
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.property().id)
      end)

    matches
  end

  def rent_property_post_more_matches_for_broker(
        user_id,
        rental_property_id,
        matches_per_broker \\ Posts.matches_per_broker(),
        broker_id
      ) do
    query =
      rental_match_base_query()
      |> where(
        [rm],
        rm.rental_property_id == ^rental_property_id and
          rm.is_relevant == true and
          rm.blocked == false
      )

    matches =
      query
      |> order_by([rm, rpp, rcp],
        asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
        desc: rm.inserted_at,
        asc: rm.edit_distance
      )
      |> where([rm, rpp, rcp], rcp.assigned_user_id == ^broker_id)
      |> select([rm, rpp, rcp], %{
        rm: rm,
        assigned_user_id: rcp.assigned_user_id,
        rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rcp.assigned_user_id, rcp.inserted_at)
      })
      |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
      |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
      |> Repo.all()
      |> Enum.filter(
        &(&1.rank > matches_per_broker &&
            !is_nil(&1.rm.rental_client.assigned_user))
      )
      |> Enum.map(fn %{rm: rm} ->
        rp = rm.rental_client
        MatchHelper.structured_post_match_keys(rm, user_id, rp, PostType.rent().id, PostSubType.client().id)
      end)

    matches
  end

  @doc """
  Rental matches for broker properties with logged-in-user
  """
  def rental_matches_with_broker_properties_query(logged_user_id, broker_id) do
    RentalMatch
    |> join(:inner, [rm], rcp in RentalClientPost,
      on:
        rm.rental_client_id == rcp.id and
          rcp.assigned_user_id == ^logged_user_id and
          rcp.archived == false and
          fragment("? >= timezone('utc', NOW())", rcp.expires_in)
    )
    |> join(:inner, [rm, rcp], rpp in RentalPropertyPost,
      on:
        rm.rental_property_id == rpp.id and
          rpp.assigned_user_id == ^broker_id and
          rpp.archived == false and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
    )
    |> join(:left, [rm, rcp, rpp], rrpp in ReportedRentalPropertyPost,
      on:
        rrpp.reported_by_id == ^logged_user_id and
          rpp.id == rrpp.rental_property_id
    )
    |> where([rm, rcp, rpp, rrpp], rm.is_relevant == true and rm.blocked == false and is_nil(rrpp.id))
    |> where(
      [rm, rcp, rpp],
      (rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true)
    )
    |> order_by([rm, rcp, rpp],
      asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
      desc: rm.inserted_at,
      asc: rm.edit_distance
    )
    |> select([rm, rcp, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id,
      rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_property_id, rm.inserted_at)
    })
    |> preload(
      rental_client: [assigned_user: [:broker, :broker_role, :organization]],
      rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]]
    )
  end

  def rental_matches_with_broker_properties_formatting(results, logged_user_id, _broker_id) do
    results
    |> Enum.filter(&(&1.rank == 1))
    |> Enum.map(fn %{rm: rm, rental_property_id: rental_property_id} ->
      rp = rm.rental_property

      match = MatchHelper.structured_post_match_keys(rm, logged_user_id, rp, PostType.rent().id, PostSubType.property().id)

      is_read = MatchHelper.rental_property_is_read(rental_property_id, logged_user_id)
      match = match |> Map.merge(%{read: is_read})
      %{post_in_context: match, has_more_matches: false}
    end)
  end

  def rental_matches_with_broker_properties(logged_user_id, broker_id, _matches_per_post \\ 1) do
    rental_matches_with_broker_properties_query(logged_user_id, broker_id)
    |> Repo.all()
    # |> Enum.filter(&(&1.rank <= matches_per_post)) # NOTE: Restrict matches per post
    |> rental_matches_with_broker_properties_formatting(logged_user_id, broker_id)
  end

  def rental_outstanding_matches_with_broker_properties(logged_user_id, broker_id, _matches_per_post \\ 1) do
    rental_matches_with_broker_properties_query(logged_user_id, broker_id)
    |> where([rm, _, _], is_nil(rm.outgoing_call_log_id) and rm.already_contacted == false)
    |> Repo.all()
    # |> Enum.filter(&(&1.rank <= matches_per_post)) # NOTE: Restrict matches per post
    |> rental_matches_with_broker_properties_formatting(logged_user_id, broker_id)
  end

  # used in matches home page api for getting top matches of post
  def rental_client_posts_with_matches(logged_user_id, match_count, include_owners \\ false) do
    reported_rental_property_ids = ReportedRentalPropertyPost.get_reported_rental_property_ids(logged_user_id)

    query =
      RentalMatch
      |> join(:inner, [rm], rcp in RentalClientPost,
        on:
          rm.rental_client_id == rcp.id and
            rcp.assigned_user_id == ^logged_user_id and
            rcp.archived == false and
            fragment("? >= timezone('utc', NOW())", rcp.expires_in)
      )
      |> join(:inner, [rm, rcp], cred in Credential,
        on:
          rcp.assigned_user_id == cred.id and
            cred.active == true
      )

    query =
      if include_owners do
        query
        |> join(:inner, [rm, rcp, cred], rpp in RentalPropertyPost,
          on:
            rm.rental_property_id == rpp.id and
              (is_nil(rpp.assigned_user_id) or rpp.assigned_user_id != ^logged_user_id) and
              rpp.archived == false and
              not (rpp.uploader_type != "owner" and rpp.id in ^reported_rental_property_ids) and
              fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      else
        query
        |> join(:inner, [rm, rcp, cred], rpp in RentalPropertyPost,
          on:
            rm.rental_property_id == rpp.id and
              rpp.assigned_user_id != ^logged_user_id and
              rpp.archived == false and
              rpp.id not in ^reported_rental_property_ids and
              fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      end

    query
    |> where([rm, rcp, cred, rpp], rm.is_relevant == true and rm.blocked == false)
    |> where(
      [rm, rcp, cred, rpp],
      (rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true)
    )
    |> order_by([rm, rcp, cred, rpp],
      # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
      desc: rm.inserted_at
      # asc: rm.edit_distance
    )
    |> select([rm, rcp, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id
      # rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_property_id, rm.inserted_at)
    })
    |> preload(
      rental_client: [assigned_user: [:broker, :broker_role, :organization]],
      rental_property: [:building, :assigned_owner, assigned_user: [:broker, :broker_role, :organization]]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.rental_client_id)
    |> Enum.map(fn {rental_client_id, arr_v} ->
      post_in_context = rent_client_post_context(logged_user_id, rental_client_id)

      is_any_perfect_match = arr_v |> Enum.filter(&(&1.rm.edit_distance |> Decimal.to_float() == 0)) |> length |> (&(&1 != 0)).()

      call_log_time = MatchHelper.rental_client_call_log_time(rental_client_id)

      post_in_context =
        post_in_context
        |> Map.merge(%{
          perfect_match: is_any_perfect_match,
          call_log_time: call_log_time
        })

      total_matches_count = arr_v |> length

      range = 0..(match_count - 1)

      matches =
        if include_owners do
          arr_v
        else
          arr_v
          |> Enum.filter(
            # &1.rank <= matches_per_broker
            # &&
            &(!is_nil(&1.rm.rental_property.assigned_user))
          )
        end

      matches =
        matches
        |> Enum.map(fn %{rm: rm} ->
          rp = rm.rental_property

          match =
            MatchHelper.structured_post_match_keys(
              rm,
              logged_user_id,
              rp,
              PostType.rent().id,
              PostSubType.property().id
            )

          is_read = MatchHelper.rental_property_is_read(rp.id, logged_user_id)
          match |> Map.merge(%{read: is_read})
        end)
        # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
        |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
        |> Enum.slice(range)

      %{
        post_in_context: post_in_context,
        matches: matches,
        total_matches_count: total_matches_count,
        has_more_posts: length(matches) < total_matches_count
      }
    end)
  end

  def rental_client_posts_without_matches(logged_user_id, rental_client_posts) do
    uuids =
      rental_client_posts
      |> Enum.map(fn %{post_in_context: pic} ->
        uuid = pic.uuid
        uuid |> String.split("rent/client/") |> Enum.at(1)
      end)

    RentalClientPost
    |> join(:inner, [rcp], cred in Credential,
      on:
        rcp.assigned_user_id == cred.id and
          cred.active == true
    )
    |> where(
      [rcp, cred],
      rcp.assigned_user_id == ^logged_user_id and
        rcp.uuid not in ^uuids and
        rcp.archived == false and
        fragment("? >= timezone('utc', NOW())", rcp.expires_in)
    )
    |> Repo.all()
    |> Enum.map(fn rcp ->
      post_in_context = rent_client_post_context(logged_user_id, rcp.id)

      %{
        post_in_context: post_in_context,
        matches: [],
        total_matches_count: 0
      }
    end)
  end

  def rental_property_posts_with_matches(logged_user_id, match_count, include_owners \\ false) do
    reported_rental_client_post_ids = ReportedRentalClientPost.get_reported_rental_client_post_ids(logged_user_id)

    query =
      RentalMatch
      |> join(:inner, [rm], rcp in RentalClientPost,
        on:
          rm.rental_client_id == rcp.id and
            rcp.assigned_user_id != ^logged_user_id and
            rcp.archived == false and
            rcp.id not in ^reported_rental_client_post_ids and
            fragment("? >= timezone('utc', NOW())", rcp.expires_in)
      )
      |> join(:inner, [rm, rcp], cred in Credential,
        on:
          rcp.assigned_user_id == cred.id and
            cred.active == true
      )

    query =
      if include_owners do
        query
        |> join(:inner, [rm, rcp, cred], rpp in RentalPropertyPost,
          on:
            rm.rental_property_id == rpp.id and
              (is_nil(rpp.assigned_user_id) or rpp.assigned_user_id == ^logged_user_id) and
              rpp.archived == false and
              fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      else
        query
        |> join(:inner, [rm, rcp, cred], rpp in RentalPropertyPost,
          on:
            rm.rental_property_id == rpp.id and
              rpp.assigned_user_id == ^logged_user_id and
              rpp.archived == false and
              fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      end

    query
    |> where([rm, rcp, cred, rpp], rm.is_relevant == true and rm.blocked == false)
    |> where(
      [rm, rcp, cred, rpp],
      (rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true)
    )
    |> order_by([rm, rcp, cred, rpp],
      # asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
      desc: rm.inserted_at
      # asc: rm.edit_distance
    )
    |> select([rm, rcp, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id
      # rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_client_id, rm.inserted_at)
    })
    |> preload(
      rental_client: [assigned_user: [:broker, :broker_role, :organization]],
      rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]]
    )
    |> Repo.all()
    |> Enum.group_by(& &1.rental_property_id)
    |> Enum.map(fn {rental_property_id, arr_v} ->
      post_in_context = rent_property_post_context(logged_user_id, rental_property_id)

      is_any_perfect_match = arr_v |> Enum.filter(&(&1.rm.edit_distance |> Decimal.to_float() == 0)) |> length |> (&(&1 != 0)).()

      call_log_time = MatchHelper.rental_property_call_log_time(rental_property_id)

      post_in_context =
        post_in_context
        |> Map.merge(%{
          perfect_match: is_any_perfect_match,
          call_log_time: call_log_time
        })

      total_matches_count = arr_v |> length

      range = 0..(match_count - 1)

      matches =
        arr_v
        |> Enum.filter(
          # &1.rank <= matches_per_broker
          # &&
          &(!is_nil(&1.rm.rental_client.assigned_user))
        )
        |> Enum.map(fn %{rm: rm} ->
          rp = rm.rental_client

          match = MatchHelper.structured_post_match_keys(rm, logged_user_id, rp, PostType.rent().id, PostSubType.client().id)

          is_read = MatchHelper.rental_client_is_read(rp.id, logged_user_id)
          match |> Map.merge(%{read: is_read})
        end)
        # |> Enum.sort_by(fn(post) -> {post.read == false, post.inserted_at || post.updation_time} end, &>=/2)
        |> Enum.sort_by(fn post -> {post.inserted_at} end, &>=/2)
        |> Enum.slice(range)

      %{
        post_in_context: post_in_context,
        matches: matches,
        total_matches_count: total_matches_count,
        has_more_posts: length(matches) < total_matches_count
      }
    end)
  end

  def rental_property_posts_without_matches(logged_user_id, rental_property_posts, include_owners \\ false) do
    uuids =
      rental_property_posts
      |> Enum.map(fn %{post_in_context: pic} ->
        uuid = pic.uuid
        uuid |> String.split("rent/property/") |> Enum.at(1)
      end)

    query =
      if include_owners do
        RentalPropertyPost
        |> join(:left, [rpp], cred in Credential,
          on:
            rpp.assigned_user_id == cred.id and
              (is_nil(cred.active) or cred.active == true)
        )
        |> where(
          [rpp, cred],
          (is_nil(rpp.assigned_user_id) or rpp.assigned_user_id == ^logged_user_id) and
            rpp.uuid not in ^uuids and
            rpp.archived == false and
            fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      else
        RentalPropertyPost
        |> join(:inner, [rpp], cred in Credential,
          on:
            rpp.assigned_user_id == cred.id and
              cred.active == true
        )
        |> where(
          [rpp, cred],
          rpp.assigned_user_id == ^logged_user_id and
            rpp.uuid not in ^uuids and
            rpp.archived == false and
            fragment("? >= timezone('utc', NOW())", rpp.expires_in)
        )
      end

    query
    |> Repo.all()
    |> Enum.map(fn rpp ->
      post_in_context = rent_property_post_context(logged_user_id, rpp.id)

      %{
        post_in_context: post_in_context,
        matches: [],
        total_matches_count: 0
      }
    end)
  end

  @doc """
  Rental matches for broker clients with logged-in-user
  """
  def rental_matches_with_broker_clients_query(logged_user_id, broker_id) do
    RentalMatch
    |> join(:inner, [rm], rcp in RentalClientPost,
      on:
        rm.rental_client_id == rcp.id and
          rcp.assigned_user_id == ^broker_id and
          rcp.archived == false and
          fragment("? >= timezone('utc', NOW())", rcp.expires_in)
    )
    |> join(:inner, [rm, rcp], rpp in RentalPropertyPost,
      on:
        rm.rental_property_id == rpp.id and
          rpp.assigned_user_id == ^logged_user_id and
          rpp.archived == false and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
    )
    |> join(:left, [rm, rcp, rpp], rrcp in ReportedRentalClientPost,
      on:
        rrcp.reported_by_id == ^logged_user_id and
          rcp.id == rrcp.rental_client_id
    )
    |> where([rm, rcp, rpp, rrcp], rm.is_relevant == true and rm.blocked == false and is_nil(rrcp.id))
    |> where(
      [rm, rcp, rpp],
      (rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true)
    )
    |> order_by([rm, rcp, rpp],
      asc: fragment("? IS NOT NULL", rm.outgoing_call_log_id),
      desc: rm.inserted_at,
      asc: rm.edit_distance
    )
    |> select([rm, rcp, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id,
      rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_client_id, rm.inserted_at)
    })
    |> preload(
      rental_client: [assigned_user: [:broker, :broker_role, :organization]],
      rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]]
    )
  end

  def rental_matches_with_broker_clients_formatting(results, logged_user_id, _broker_id) do
    results
    |> Enum.filter(&(&1.rank == 1))
    |> Enum.map(fn %{rm: rm, rental_client_id: rental_client_id} ->
      rp = rm.rental_client

      match = MatchHelper.structured_post_match_keys(rm, logged_user_id, rp, PostType.rent().id, PostSubType.client().id)

      is_read = MatchHelper.rental_client_is_read(rental_client_id, logged_user_id)
      match = match |> Map.merge(%{read: is_read})
      %{post_in_context: match, has_more_matches: false}
    end)
  end

  def rental_matches_with_broker_clients(logged_user_id, broker_id, _matches_per_post \\ 1) do
    rental_matches_with_broker_clients_query(logged_user_id, broker_id)
    |> Repo.all()
    # |> Enum.filter(&(&1.rank <= matches_per_post)) # NOTE: Restrict matches per post
    |> rental_matches_with_broker_clients_formatting(logged_user_id, broker_id)
  end

  def rental_outstanding_matches_with_broker_clients(logged_user_id, broker_id, _matches_per_post \\ 1) do
    rental_matches_with_broker_clients_query(logged_user_id, broker_id)
    |> where([rm, _, _], is_nil(rm.outgoing_call_log_id) and rm.already_contacted == false)
    |> Repo.all()
    |> rental_matches_with_broker_clients_formatting(logged_user_id, broker_id)
  end

  #
  # ============ METHODS FOR MATCHES ON DASHBOARD =============
  #

  def rental_matches_with_user_properties_query(logged_user_id) do
    rental_match_base_query()
    |> where([rm, rpp], rm.is_relevant == true and rm.blocked == false and rpp.assigned_user_id == ^logged_user_id)
    |> order_by([rm, rpp],
      desc: rm.inserted_at,
      asc: rm.edit_distance
    )
    |> select([rm, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id,
      rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_client_id, rm.inserted_at)
    })
    |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
    |> preload(rental_property: [assigned_user: [:broker, :broker_role, :organization]])
  end

  def rental_matches_with_user_properties_formatting(results, logged_user_id) do
    results
    |> Enum.filter(&(&1.rank == 1))
    |> Enum.map(fn %{rm: rm, rental_client_id: rental_client_id} ->
      rp = rm.rental_client

      match = MatchHelper.structured_post_match_keys(rm, logged_user_id, rp, PostType.rent().id, PostSubType.client().id)

      is_read = MatchHelper.rental_client_is_read(rental_client_id, logged_user_id)
      match = match |> Map.merge(%{read: is_read})
      %{post_in_context: match}
    end)
  end

  def rental_matches_with_user_clients_query(logged_user_id) do
    RentalMatch
    |> join(:inner, [rm], rcp in RentalClientPost,
      on:
        rm.rental_client_id == rcp.id and
          rcp.assigned_user_id == ^logged_user_id and
          rcp.archived == false and
          fragment("? >= timezone('utc', NOW())", rcp.expires_in)
    )
    |> join(:inner, [rm, rcp], rpp in RentalPropertyPost,
      on:
        rm.rental_property_id == rpp.id and
          rpp.archived == false and
          fragment("? >= timezone('utc', NOW())", rpp.expires_in)
    )
    |> where([rm, rcp, rpp], rm.is_relevant == true and rm.blocked == false)
    |> where(
      [rm, rcp, rpp],
      (rcp.test_post == false and rpp.test_post == false) or (rcp.test_post == true and rpp.test_post == true)
    )
    |> order_by([rm, rcp, rpp],
      desc: rm.inserted_at,
      asc: rm.edit_distance
    )
    |> select([rm, rcp, rpp], %{
      rm: rm,
      rental_client_id: rm.rental_client_id,
      rental_property_id: rm.rental_property_id,
      rank: fragment("RANK () OVER(PARTITION BY ? ORDER BY ? DESC)", rm.rental_property_id, rm.inserted_at)
    })
    |> preload(rental_property: [:building, assigned_user: [:broker, :broker_role, :organization]])
    |> preload(rental_client: [assigned_user: [:broker, :broker_role, :organization]])
  end

  def rental_matches_with_user_clients_formatting(results, logged_user_id) do
    results
    |> Enum.filter(&(&1.rank == 1))
    |> Enum.map(fn %{rm: rm, rental_property_id: rental_property_id} ->
      rp = rm.rental_property

      match = MatchHelper.structured_post_match_keys(rm, logged_user_id, rp, PostType.rent().id, PostSubType.property().id)

      is_read = MatchHelper.rental_property_is_read(rental_property_id, logged_user_id)
      match = match |> Map.merge(%{read: is_read})
      %{post_in_context: match}
    end)
  end

  def rental_all_outstanding_matches_with_user_properties(logged_user_id) do
    rental_matches_with_user_properties_query(logged_user_id)
    |> Repo.all()
    |> rental_matches_with_user_properties_formatting(logged_user_id)
  end

  def rental_all_outstanding_matches_with_user_clients(logged_user_id) do
    rental_matches_with_user_clients_query(logged_user_id)
    |> Repo.all()
    |> rental_matches_with_user_clients_formatting(logged_user_id)
  end

  def rental_all_contacted_matches_with_user_properties(logged_user_id) do
    rental_matches_with_user_properties_query(logged_user_id)
    |> where([rm, _, _], is_nil(rm.outgoing_call_log_id) and rm.already_contacted == true)
    |> Repo.all()
    |> rental_matches_with_user_properties_formatting(logged_user_id)
  end

  def rental_all_contacted_matches_with_user_clients(logged_user_id) do
    rental_matches_with_user_clients_query(logged_user_id)
    |> where([rm, _, _], is_nil(rm.outgoing_call_log_id) and rm.already_contacted == true)
    |> Repo.all()
    |> rental_matches_with_user_clients_formatting(logged_user_id)
  end

  def rental_all_read_matches_with_user_properties(logged_user_id) do
    rental_matches_with_user_properties_query(logged_user_id)
    |> where([rm, _, _], not is_nil(rm.outgoing_call_log_id))
    |> Repo.all()
    |> Enum.group_by(& &1.rental_client_id)
    |> Enum.map(fn {rental_client_id, arr_v} ->
      post_in_context = rent_client_post_context(logged_user_id, rental_client_id)

      is_any_perfect_match = arr_v |> Enum.filter(&(&1.rm.edit_distance |> Decimal.to_float() == 0)) |> length |> (&(&1 != 0)).()

      call_log_time = MatchHelper.rental_client_call_log_time(rental_client_id)

      post_in_context =
        post_in_context
        |> Map.merge(%{
          perfect_match: is_any_perfect_match,
          call_log_time: call_log_time
        })

      %{
        post_in_context: post_in_context
      }
    end)
  end

  def rental_all_read_matches_with_user_clients(logged_user_id) do
    rental_matches_with_user_clients_query(logged_user_id)
    |> where([rm, _, _], not is_nil(rm.outgoing_call_log_id))
    |> Repo.all()
    |> Enum.group_by(& &1.rental_property_id)
    |> Enum.map(fn {rental_property_id, arr_v} ->
      post_in_context = rent_property_post_context(logged_user_id, rental_property_id)

      is_any_perfect_match = arr_v |> Enum.filter(&(&1.rm.edit_distance |> Decimal.to_float() == 0)) |> length |> (&(&1 != 0)).()

      call_log_time = MatchHelper.rental_property_call_log_time(rental_property_id)

      post_in_context =
        post_in_context
        |> Map.merge(%{
          perfect_match: is_any_perfect_match,
          call_log_time: call_log_time
        })

      %{
        post_in_context: post_in_context
      }
    end)
  end

  def latest_outstanding_rental_client_match_date(broker_id) do
    rental_match_base_query()
    |> where(
      [rm, rpp, rcp],
      rm.is_relevant == true and
        rm.blocked == false and
        is_nil(rm.outgoing_call_log_id) and
        rm.already_contacted == false and
        rcp.assigned_user_id == ^broker_id
    )
    |> order_by([rm], desc: rm.inserted_at)
    |> limit(1)
    |> select([rm], fragment("ROUND(extract(epoch from ?))", rm.inserted_at))
    |> Repo.one()
  end

  def latest_outstanding_rental_property_match_date(broker_id) do
    rental_match_base_query()
    |> where(
      [rm, rpp, rcp],
      rm.is_relevant == true and
        rm.blocked == false and
        is_nil(rm.outgoing_call_log_id) and
        rm.already_contacted == false and
        rpp.assigned_user_id == ^broker_id
    )
    |> order_by([rm], desc: rm.inserted_at)
    |> limit(1)
    |> select([rm], fragment("ROUND(extract(epoch from ?))", rm.inserted_at))
    |> Repo.one()
  end

  def latest_rental_client_match_date(broker_id) do
    rental_match_base_query()
    |> where(
      [rm, rpp, rcp],
      rm.is_relevant == true and
        rm.blocked == false and
        rcp.assigned_user_id == ^broker_id
    )
    |> order_by([rm], desc: rm.inserted_at)
    |> limit(1)
    |> select([rm], fragment("ROUND(extract(epoch from ?))", rm.inserted_at))
    |> Repo.one()
  end

  def latest_rental_property_match_date(broker_id) do
    rental_match_base_query()
    |> where(
      [rm, rpp, rcp],
      rm.is_relevant == true and
        rm.blocked == false and
        rpp.assigned_user_id == ^broker_id
    )
    |> order_by([rm], desc: rm.inserted_at)
    |> limit(1)
    |> select([rm], fragment("ROUND(extract(epoch from ?))", rm.inserted_at))
    |> Repo.one()
  end

  # ================================

  @doc """
   1. Given client ids and property_ids fetches all matches
   2. Sorted on edit_distance
  """
  def get_matches_data(client_ids, property_ids) do
    RentalMatch
    |> where(
      [rm],
      rm.rental_client_id in ^client_ids and
        rm.rental_property_id in ^property_ids and
        rm.is_relevant == true and
        rm.blocked == false
    )
    |> order_by([rm], rm.edit_distance)
    |> Repo.all()
  end

  def assign_all_posts_to_me(user_id, logged_user_id) do
    RentalClientPost
    |> where(assigned_user_id: ^user_id)
    |> update(set: [assigned_user_id: ^logged_user_id])
    |> Repo.update_all([])

    RentalPropertyPost
    |> where(assigned_user_id: ^user_id)
    |> update(set: [assigned_user_id: ^logged_user_id])
    |> Repo.update_all([])
  end

  # BEFORE COMMIT METHODS

  @doc """
  Provided Uncomitted Rent Client Post Params,
  Returns: Rent Property probable matches count
  """
  def rent_property_matches_count_query(
        assigned_user_id,
        configuration_type_ids,
        building_ids,
        is_bachelor,
        blocked_users \\ [],
        test_post \\ false,
        params \\ %{}
      ) do
    RentalPropertyPost
    |> join(:inner, [rpp], cred in Credential, on: rpp.assigned_user_id == cred.id)
    |> join(:inner, [rpp, cred], building in Building, on: building.id == rpp.building_id)
    |> join(:inner, [rpp, cred, building], p in Polygon, on: p.id == building.polygon_id)
    |> join(:left, [rpp, cred, building], rrpp in ReportedRentalPropertyPost,
      on:
        rrpp.reported_by_id == ^assigned_user_id and
          rpp.id == rrpp.rental_property_id
    )
    |> where(
      [rpp, cred, building, p, rrpp],
      rpp.building_id in ^building_ids and
        (not (^is_bachelor) or not (rpp.is_bachelor_allowed == false)) and
        rpp.test_post == ^test_post and
        fragment("? >= timezone('utc', NOW())", rpp.expires_in) and
        rpp.archived == false and
        cred.active == true and
        not (rpp.assigned_user_id == ^assigned_user_id) and
        cred.id not in ^blocked_users and
        is_nil(rrpp.id)
    )
    |> dynamic_rent_property_match_count_query(params, configuration_type_ids)
    |> group_by([rpp, _cred, _building, _p], rpp.assigned_user_id)
    |> select([rpp, _, _, _], %{user_id: rpp.assigned_user_id, count: count(rpp.id)})
  end

  @doc """
  Provided Property Post Params, Get Rent Client Matches
  """
  def rent_client_matches_count_query(
        assigned_user_id,
        configuration_type_id,
        building_id,
        is_bachelor_allowed,
        blocked_users \\ [],
        test_post \\ false,
        params \\ %{}
      ) do
    RentalClientPost
    |> join(:inner, [rcp], cred in Credential, on: rcp.assigned_user_id == cred.id)
    |> join(:inner, [rcp, cred], building in Building, on: building.id in rcp.building_ids)
    |> join(:inner, [rcp, cred, building], p in Polygon, on: p.id == building.polygon_id)
    |> join(:left, [rcp, cred, building], rrcp in ReportedRentalClientPost,
      on:
        rrcp.reported_by_id == ^assigned_user_id and
          rcp.id == rrcp.rental_client_id
    )
    |> where(
      [rcp, cred, building, p, rrcp],
      ^building_id in rcp.building_ids and
        (^is_bachelor_allowed or not (rcp.is_bachelor == true)) and
        fragment("? >= timezone('utc', NOW())", rcp.expires_in) and
        building.id == ^building_id and
        rcp.archived == false and
        rcp.test_post == ^test_post and
        cred.active == true and
        not (rcp.assigned_user_id == ^assigned_user_id) and
        cred.id not in ^blocked_users and
        is_nil(rrcp.id)
    )
    |> dynamic_rent_client_match_count_query(params, configuration_type_id)
    |> group_by([rcp, _cred, _building, _p], rcp.assigned_user_id)
    |> select([rcp, _, _, _], %{user_id: rcp.assigned_user_id, count: count(rcp.id)})
  end

  defp dynamic_rent_property_match_count_query(query, params, configuration_type_ids) do
    max_rent = params["max_rent"] |> String.to_integer()
    furnishing_type_ids = params["furnishing_type_ids"]

    query
    |> where(
      [rpp, cred, building, p],
      not fragment("?->'rent_expected'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "?::int >= ? OR (? BETWEEN ?::int * (1 - (?->'rent_expected'->>'min')::float) and ?::int * (1 + (?->'rent_expected'->>'max')::float))",
          ^max_rent,
          rpp.rent_expected,
          rpp.rent_expected,
          ^max_rent,
          p.rent_match_parameters,
          ^max_rent,
          p.rent_match_parameters
        )
    )
    |> where(
      [rpp, cred, building, p],
      not fragment("?->'furnishing_type_id'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "
        CASE WHEN ? = 1 THEN (?->'furnishing_type_id'->'1')
          WHEN ? = 2 THEN (?->'furnishing_type_id'->'2')
          ELSE ?->'furnishing_type_id'->'3'
        END \\?| ?::text[]",
          rpp.furnishing_type_id,
          p.rent_match_parameters,
          rpp.furnishing_type_id,
          p.rent_match_parameters,
          p.rent_match_parameters,
          ^furnishing_type_ids
        )
    )
    |> where(
      [rpp, cred, building, p],
      not fragment("?->'configuration_type_id'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "
        CASE WHEN ? = 1 THEN (?->'configuration_type_id'->'1')
          WHEN ? = 2 THEN (?->'configuration_type_id'->'2')
          WHEN ? = 3 THEN (?->'configuration_type_id'->'3')
          WHEN ? = 4 THEN (?->'configuration_type_id'->'4')
          WHEN ? = 5 THEN (?->'configuration_type_id'->'5')
          WHEN ? = 6 THEN (?->'configuration_type_id'->'6')
          WHEN ? = 7 THEN (?->'configuration_type_id'->'7')
          WHEN ? = 8 THEN (?->'configuration_type_id'->'8')
          ELSE ?->'configuration_type_id'->'9'
        END \\?| ?::text[]",
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          rpp.configuration_type_id,
          p.rent_match_parameters,
          p.rent_match_parameters,
          ^configuration_type_ids
        )
    )
  end

  defp dynamic_rent_client_match_count_query(query, params, configuration_type_id) do
    rent_expected = params["rent_expected"] |> String.to_integer()
    furnishing_type_id = params["furnishing_type_id"] |> String.to_integer()
    configuration_type_id = configuration_type_id |> String.to_integer()

    query
    |> where(
      [rcp, cred, building, p],
      not fragment("?->'rent_expected'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "? >= ?::int OR (?::int BETWEEN ? * (1 - (?->'rent_expected'->>'min')::float) and ?::int * (1 + (?->'rent_expected'->>'max')::float))",
          rcp.max_rent,
          ^rent_expected,
          ^rent_expected,
          rcp.max_rent,
          p.rent_match_parameters,
          rcp.max_rent,
          p.rent_match_parameters
        )
    )
    |> where(
      [rcp, cred, building, p],
      not fragment("?->'furnishing_type_id'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "
        CASE WHEN ?::int = 1 THEN (?->'furnishing_type_id'->'1')
          WHEN ?::int = 2 THEN (?->'furnishing_type_id'->'2')
          ELSE ?->'furnishing_type_id'->'3'
        END \\?| ?::text[]",
          ^furnishing_type_id,
          p.rent_match_parameters,
          ^furnishing_type_id,
          p.rent_match_parameters,
          p.rent_match_parameters,
          rcp.furnishing_type_ids
        )
    )
    |> where(
      [rcp, cred, building, p],
      not fragment("?->'configuration_type_id'->>'filter' = 'true'", p.rent_match_parameters) or
        fragment(
          "
        CASE WHEN ?::int = 1 THEN (?->'configuration_type_id'->'1')
          WHEN ?::int = 2 THEN (?->'configuration_type_id'->'2')
          WHEN ?::int = 3 THEN (?->'configuration_type_id'->'3')
          WHEN ?::int = 4 THEN (?->'configuration_type_id'->'4')
          WHEN ?::int = 5 THEN (?->'configuration_type_id'->'5')
          WHEN ?::int = 6 THEN (?->'configuration_type_id'->'6')
          WHEN ?::int = 7 THEN (?->'configuration_type_id'->'7')
          WHEN ?::int = 8 THEN (?->'configuration_type_id'->'8')
          ELSE ?->'configuration_type_id'->'9'
        END \\?| ?::text[]",
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          ^configuration_type_id,
          p.rent_match_parameters,
          p.rent_match_parameters,
          rcp.configuration_type_ids
        )
    )
  end

  def fetch_rent_matched_property_ids(client_post_id) do
    RentalMatch
    |> where([rm], rm.rental_client_id == ^client_post_id)
    |> select([rm], rm.rental_property_id)
    |> Repo.all()
  end

  def fetch_rent_matched_client_ids(property_post_id) do
    RentalMatch
    |> where([rm], rm.rental_property_id == ^property_post_id)
    |> select([rm], rm.rental_client_id)
    |> Repo.all()
  end

  def fetch_latest_match(assigned_user_id) do
    RentalMatch
    |> join(:inner, [rm], rcp in RentalClientPost, on: rm.rental_client_id == rcp.id)
    |> join(:inner, [rm, rcp], rpp in RentalPropertyPost, on: rm.rental_property_id == rpp.id)
    |> where([rm, rcp, rpp], rcp.assigned_user_id == ^assigned_user_id or rpp.assigned_user_id == ^assigned_user_id)
    |> order_by([rm], desc: rm.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def fetch_owner_matches(params) do
    page =
      case not is_nil(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 10
      end

    owner_property_id = params["id"]

    query =
      RentalMatch
      |> join(:inner, [rm], rpp in RentalPropertyPost, on: rm.rental_property_id == rpp.id)
      |> join(:inner, [rm, rpp], rcp in RentalClientPost, on: rm.rental_client_id == rcp.id)
      |> join(:inner, [rm, rpp, rcp], c in Credential, on: c.id == rcp.assigned_user_id)
      |> join(:inner, [rm, rpp, rcp, c], bro in Broker, on: c.broker_id == bro.id)
      |> join(:inner, [rm, rpp, rcp, c, bro], mps in MatchPlusSubscription, on: bro.id == mps.broker_id)
      |> where([rm, rpp], rpp.uploader_type == "owner" and rpp.id == ^owner_property_id)
      |> select([rm, rpp, rcp, c, bro, mps], %{
        client_post_id: rcp.id,
        id: rm.id,
        already_contacted_by: rm.already_contacted_by,
        already_contacted: rm.already_contacted,
        property_post_id: rpp.id,
        broker: %{
          name: bro.name,
          id: bro.id,
          phone_number: c.phone_number,
          active: c.active,
          is_match_plus_active:
            fragment(
              "
              CASE
                WHEN ? = 1
                  THEN true
                ELSE
                  false
              END
              ",
              mps.status_id
            )
        }
      })

    matches =
      query
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> Repo.all()
      |> Enum.map(fn rm ->
        rm
        |> Map.put(:client_post, RentalClientPost.get_post(rm.client_post_id))
        |> Map.put(:property_post, RentalPropertyPost.get_post(rm.property_post_id))
      end)

    total_count = query |> Repo.aggregate(:count, :id)
    has_more_matches = page < Float.ceil(total_count / size)
    {matches, total_count, has_more_matches}
  end

  def fetch_all_matches(params) do
    page =
      case not is_nil(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 10
      end

    query =
      RentalMatch
      |> join(:inner, [rm], rpp in RentalPropertyPost, on: rm.rental_property_id == rpp.id)
      |> join(:inner, [rm, rpp], rcp in RentalClientPost, on: rm.rental_client_id == rcp.id)
      |> join(:left, [rm, rpp, rcp], c in Credential, on: c.id == rcp.assigned_user_id)
      |> join(:left, [rm, rpp, rcp, c], bro in Broker, on: c.broker_id == bro.id)
      |> select([rm, rpp, rcp, c, bro], %{
        client_post_id: rcp.id,
        id: rm.id,
        already_contacted_by: rm.already_contacted_by,
        already_contacted: rm.already_contacted,
        property_post_id: rpp.id,
        inserted_at: rm.inserted_at
      })

    matches =
      query
      |> limit(^size)
      |> order_by([rm], desc: rm.inserted_at)
      |> offset(^((page - 1) * size))
      |> Repo.all()
      |> Enum.map(fn rm ->
        rm
        |> Map.put(:client_post, RentalClientPost.get_post(rm.client_post_id))
        |> Map.put(:property_post, RentalPropertyPost.get_post(rm.property_post_id))
      end)

    total_count = query |> Repo.aggregate(:count, :id)
    has_more_matches = page < Float.ceil(total_count / size)
    {matches, total_count, has_more_matches}
  end
end
