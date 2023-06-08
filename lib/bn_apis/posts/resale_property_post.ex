defmodule BnApis.Posts.ResalePropertyPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Places.Polygon
  alias BnApis.Helpers.S3Helper
  alias BnApis.Buildings.Building
  alias BnApis.Buildings
  alias BnApis.Posts
  alias BnApis.Accounts
  alias BnApis.Accounts.{Credential, EmployeeCredential, Owner}
  alias BnApis.Posts.{ConfigurationType, FloorType}
  alias BnApis.Repo
  alias BnApis.Helpers.Utils

  alias BnApis.Posts.{
    ResalePropertyPost,
    ResaleClientPost,
    ResaleMatch,
    ReportedResalePropertyPost,
    ContactedResalePropertyPost
  }

  alias BnApis.Helpers.{Time, Utils, HtmlHelper, GoogleMapsHelper}
  alias BnApis.Reasons.Reason
  alias BnApisWeb.Helpers.BuildingHelper
  alias BnApis.Buildings.Building
  alias BnApis.AssistedProperty.Schema.AssistedPropertyPostAgreement
  alias BnApis.AssistedProperty

  schema "resale_property_posts" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :carpet_area, :integer
    field :notes, :string
    field :source, :string
    field :parking, :integer
    field :price, :integer

    field :uploader_type, :string

    field :archived, :boolean, default: false
    field :is_verified, :boolean, default: false
    field :expires_in, :naive_datetime
    field :updation_time, :naive_datetime
    field :last_archived_at, :naive_datetime
    field :last_verified_at, :naive_datetime
    field :last_refreshed_at, :naive_datetime
    field :last_edited_at, :naive_datetime
    field :test_post, :boolean, default: true
    field :auto_expired_read, :boolean, default: false
    field :is_offline, :boolean, default: false
    field :raw_post_uuid, :string
    field :action_via_slash, :boolean, default: false
    field :is_assisted, :boolean, default: false

    belongs_to :archived_by, Credential
    belongs_to :refreshed_by, Credential
    belongs_to :archived_reason, Reason
    belongs_to :refreshed_reason, Reason

    belongs_to :building, Building
    belongs_to :configuration_type, ConfigurationType
    belongs_to :floor_type, FloorType
    belongs_to :user, Credential
    belongs_to :assigned_user, Credential
    belongs_to :assigned_owner, Owner, on_replace: :update
    belongs_to :employees_credentials, EmployeeCredential
    belongs_to :archived_by_employees_credentials, EmployeeCredential
    belongs_to :edited_by_employees_credentials, EmployeeCredential
    belongs_to :verified_by_employees_credentials, EmployeeCredential
    belongs_to :refreshed_by_employees_credentials, EmployeeCredential
    belongs_to :latest_assisted_property_post_agreement, AssistedPropertyPostAgreement

    has_many(:assisted_property_post_agreements, AssistedPropertyPostAgreement, foreign_key: :resale_property_post_id)

    timestamps()
  end

  @doc """
  Form Details:
  Building - Search and Select - Single Select - Mandatory
  Config - Studio/1BHK/2BHK/3BHK/4+BHK - Single Select - Mandatory
  Price - Numeric input - Mandatory
  Carpet Area - Numeric input - Mandatory
  Parking - Numeric input - Mandatory
  Floor - Low/Mid/High - Single Select - Mandatory
  Notes - Open text field - Optional
  Assigned To - Single Select from a list of teammates - Mandatory - Defaults to Current User

  """
  @fields [
    :price,
    :carpet_area,
    :parking,
    :notes,
    :assigned_user_id,
    :building_id,
    :configuration_type_id,
    :floor_type_id,
    :user_id,
    :archived,
    :expires_in,
    :archived_by_id,
    :archived_by_employees_credentials_id,
    :refreshed_by_id,
    :refreshed_by_employees_credentials_id,
    :is_offline,
    :updation_time,
    :archived_reason_id,
    :refreshed_reason_id,
    :test_post,
    :uploader_type,
    :assigned_owner_id,
    :employees_credentials_id,
    :source,
    :is_verified,
    :last_archived_at,
    :last_verified_at,
    :verified_by_employees_credentials_id,
    :edited_by_employees_credentials_id,
    :last_edited_at,
    :raw_post_uuid,
    :last_refreshed_at,
    :action_via_slash,
    :is_assisted,
    :latest_assisted_property_post_agreement_id,
    :inserted_at
  ]

  @required_fields [:building_id, :configuration_type_id, :price, :carpet_area, :parking, :floor_type_id]
  @default_radius 1000.0
  @assisted_default_radius 5000.0
  @srid 4326

  @s3_prefix_reshareable_image "reshareable_owner_image"

  def s3_prefix_reshareable_image(), do: @s3_prefix_reshareable_image

  def new(params) do
    changeset(%__MODULE__{}, params)
    |> format_changeset_result()
  end

  def changeset(resale_property_post, attrs \\ %{}) do
    resale_property_post
    |> cast(attrs, @fields)
    |> cast_assoc(:assigned_owner, with: &Owner.changeset/2)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:building_id)
    |> foreign_key_constraint(:configuration_type_id)
    |> foreign_key_constraint(:floor_type_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:assigned_user_id)
    |> foreign_key_constraint(:assigned_owner_id)
    |> foreign_key_constraint(:employees_credentials_id)
    |> foreign_key_constraint(:latest_assisted_property_post_agreement_id)
  end

  def get_post(post_id, add_building_info \\ true) do
    post =
      ResalePropertyPost
      |> where([rpp], rpp.id == ^post_id)
      |> preload([
        :archived_reason,
        :refreshed_reason,
        :assigned_owner,
        :configuration_type,
        :floor_type,
        archived_by: [:broker],
        refreshed_by: [:broker],
        assigned_user: [:broker],
        user: [:broker]
      ])
      |> Repo.all()
      |> Enum.map(fn rpp ->
        archived_by =
          if not is_nil(rpp.archived_by) do
            %{
              "id" => rpp.archived_by.broker.id,
              "name" => rpp.archived_by.broker.name,
              "phone_number" => rpp.archived_by.phone_number
            }
          else
            nil
          end

        refreshed_by =
          if not is_nil(rpp.refreshed_by) do
            %{
              "id" => rpp.refreshed_by.broker.id,
              "name" => rpp.refreshed_by.broker.name,
              "phone_number" => rpp.refreshed_by.phone_number
            }
          else
            nil
          end

        assigned_user =
          if not is_nil(rpp.assigned_user) do
            %{
              "id" => rpp.assigned_user.broker.id,
              "name" => rpp.assigned_user.broker.name,
              "phone_number" => rpp.assigned_user.phone_number
            }
          else
            nil
          end

        cc =
          if not is_nil(rpp.assigned_owner) && not is_nil(rpp.assigned_owner.country_code),
            do: rpp.assigned_owner.country_code,
            else: "+91"

        assigned_owner =
          if not is_nil(rpp.assigned_owner) do
            %{
              id: rpp.assigned_owner.id,
              uuid: rpp.assigned_owner.uuid,
              name: rpp.assigned_owner.name,
              email: rpp.assigned_owner.email,
              phone_number: rpp.assigned_owner.phone_number,
              country_code: cc,
              is_broker_flag: rpp.assigned_owner.is_broker
            }
          else
            nil
          end

        user =
          if not is_nil(rpp.assigned_user) do
            %{
              "id" => rpp.user.broker.id,
              "name" => rpp.user.broker.name,
              "phone_number" => rpp.user.phone_number
            }
          else
            nil
          end

        %{
          "uploader_type" => rpp.uploader_type,
          "carpet_area" => rpp.carpet_area,
          "notes" => rpp.notes,
          "parking" => rpp.parking,
          "price" => rpp.price,
          "uuid" => rpp.uuid,
          "assigned_user_id" => rpp.assigned_user_id,
          "assigned_owner_id" => rpp.assigned_owner_id,
          "employees_credentials_id" => rpp.employees_credentials_id,
          "building_id" => rpp.building_id,
          "configuration_type" => rpp.configuration_type.name,
          "configuration_type_id" => rpp.configuration_type_id,
          "floor_type" => rpp.floor_type.name,
          "expires_in" => rpp.expires_in |> Time.naive_to_epoch(),
          "test_post" => rpp.test_post,
          "archived" => rpp.archived,
          "archived_reason" => if(not is_nil(rpp.archived_reason), do: rpp.archived_reason.name, else: nil),
          "archived_by" => archived_by,
          "refreshed_reason" => if(not is_nil(rpp.refreshed_reason), do: rpp.refreshed_reason.name, else: nil),
          "refreshed_by" => refreshed_by,
          "assigned_user" => assigned_user,
          "assigned_owner" => assigned_owner,
          "user" => user
        }
      end)
      |> List.last()

    if add_building_info and not is_nil(post["building_id"]) do
      put_in(post, ["building_name"], hd(Building.get_building_names([post["building_id"]])))
    else
      post
    end
  end

  def get_post_by(params, preload \\ []), do: ResalePropertyPost |> Repo.get_by(params) |> Repo.preload(preload)

  def list_posts_by(params, preload \\ []) do
    where = params |> Map.to_list()

    from(ResalePropertyPost, where: ^where)
    |> Repo.all()
    |> Repo.preload(preload)
  end

  def filter_edit_fields(params, allowed_fields_list \\ []) do
    edit_fields =
      allowed_fields_list ++
        [
          "carpet_area",
          "notes",
          "source",
          "parking",
          "price",
          "test_post",
          "building_id",
          "configuration_type_id",
          "floor_type_id",
          "assigned_owner_id",
          "assigned_owner"
        ]

    params |> Map.take(edit_fields)
  end

  def mark_post_matches_irrelevant(user_id, resale_property_ids) do
    ResaleMatch
    |> join(:inner, [rm], rcp in ResaleClientPost, on: rm.resale_client_id == rcp.id and rcp.assigned_user_id == ^user_id)
    |> where([rm], rm.resale_property_id in ^resale_property_ids)
    |> update(set: [is_relevant: false])
    |> Repo.update_all([])
  end

  alias BnApis.Posts.MatchReadStatus

  def mark_post_matches_as_read(user_id, resale_property_ids) do
    ResaleMatch
    |> where([rm], rm.resale_property_id in ^resale_property_ids)
    |> Repo.all()
    |> Enum.map(fn rm ->
      %{
        read: true,
        user_id: user_id,
        resale_matches_id: rm.id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
    |> (&Repo.insert_all(MatchReadStatus, &1, on_conflict: :nothing)).()
  end

  def fetch_duplicate_posts(params) do
    {:ok, [building_id]} = Buildings.get_ids_from_uids([params["building_id"]])

    ResalePropertyPost
    |> where(
      [rpp],
      rpp.assigned_user_id == ^params["assigned_user_id"] and
        rpp.building_id == ^building_id and
        rpp.floor_type_id == ^params["floor_type_id"] and
        rpp.parking == ^params["parking"] and
        rpp.price == ^params["price"] and
        rpp.carpet_area == ^params["carpet_area"] and
        fragment("? >= timezone('utc', NOW())", rpp.expires_in)
    )
    |> Repo.all()
  end

  def check_duplicate_posts_count(params) do
    if params |> fetch_duplicate_posts() |> length() > 0,
      do: {:error, "Post with same params already exists"},
      else: {:ok, ""}
  end

  def fetch_unmatched_posts do
    {start_time, end_time} = Time.get_day_beginnning_and_end_time()

    ResalePropertyPost
    |> join(:inner, [rpp], cred in Credential, on: rpp.assigned_user_id == cred.id)
    |> join(:inner, [rpp, cred], rm in ResaleMatch, on: not (rm.resale_property_id == rpp.id) and not is_nil(cred.organization_id))
    |> where([rpp, cred, _], rpp.inserted_at >= ^start_time and rpp.inserted_at <= ^end_time)
    |> select([rpp, cred, _], %{
      id: rpp.id,
      organization_id: cred.organization_id
    })
    |> Repo.all()
  end

  def fetch_soon_to_expire_posts do
    ResalePropertyPost
    |> join(:inner, [rpp], cred in Credential, on: rpp.assigned_user_id == cred.id)
    |> where([rpp, cred], cred.active == true and not is_nil(cred.fcm_id))
    |> where([rpp, cred], fragment("?::date = current_date", rpp.expires_in))
    |> where([rpp, cred], rpp.archived == false)
    |> select([rpp, cred], %{
      fcm_id: cred.fcm_id,
      notification_platform: cred.notification_platform,
      expires_in: rpp.expires_in,
      post_uuid: rpp.uuid,
      user_id: cred.id
    })
    |> Repo.all()
  end

  alias BnApis.Posts.{PostType, PostSubType}
  alias BnApis.Posts.MatchHelper

  def fetch_posts(user_id) do
    ResalePropertyPost
    |> where([rpp], rpp.assigned_user_id == ^user_id)
    |> Repo.all()
  end

  def fetch_all_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        fragment("? >= timezone('utc', NOW())", rp.expires_in)
    )
    |> preload([:building, :latest_assisted_property_post_agreement, assigned_user: [:broker, :broker_role, :organization], latest_assisted_property_post_agreement: [:assisted_by]])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.resale().id, PostSubType.property().id, true)
    end)
  end

  def team_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        fragment("? >= timezone('utc', NOW())", rp.expires_in) and
        rp.assigned_user_id != ^user_id
    )
    |> preload([:building, :latest_assisted_property_post_agreement, assigned_user: [:broker, :broker_role, :organization], latest_assisted_property_post_agreement: [:assisted_by]])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.resale().id, PostSubType.property().id, true)
    end)
  end

  def fetch_org_user_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where([rp, cred], cred.organization_id == ^organization_id and cred.active == true)
    |> where([rp, cred], rp.assigned_user_id == ^user_id)
    |> Repo.all()
  end

  # send only auto expired posts
  def fetch_all_expired_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      # and rp.archived == false
      # and fragment("? < timezone('utc', NOW())", rp.expires_in)
      cred.organization_id == ^organization_id and
        cred.active == true and
        fragment(
          "(timezone('utc', NOW()) < timezone('utc', ? + INTERVAL '120 days') and (? < timezone('utc', NOW()))) or (? = true)",
          rp.expires_in,
          rp.expires_in,
          rp.archived
        ) and
        rp.assigned_user_id == ^user_id
    )
    |> preload([:building, :latest_assisted_property_post_agreement, assigned_user: [:broker, :broker_role, :organization], latest_assisted_property_post_agreement: [:assisted_by]])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.resale().id, PostSubType.property().id, true)
    end)
  end

  def fetch_all_unread_expired_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        rp.auto_expired_read == false and
        rp.assigned_user_id == ^user_id and
        fragment("? < timezone('utc', NOW())", rp.expires_in)
    )
    |> preload([:building, :latest_assisted_property_post_agreement, assigned_user: [:broker, :broker_role, :organization], latest_assisted_property_post_agreement: [:assisted_by]])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.resale().id, PostSubType.property().id, true)
    end)
  end

  def mark_unread_expired_posts_as_read(user_id) do
    ResalePropertyPost
    |> where(
      [rp],
      rp.archived == false and
        rp.auto_expired_read == false and
        rp.assigned_user_id == ^user_id and
        fragment("? < timezone('utc', NOW())", rp.expires_in)
    )
    |> update(set: [auto_expired_read: true])
    |> Repo.update_all([])
  end

  def fetch_all_expiring_posts(organization_id, user_id) do
    ResalePropertyPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        fragment(
          "? > timezone('utc', NOW()) AND ? < timezone('utc', NOW()) + INTERVAL '1 day' - INTERVAL '1 second'",
          rp.expires_in,
          rp.expires_in
        ) and
        rp.assigned_user_id == ^user_id
    )
    |> preload([:building, :latest_assisted_property_post_agreement, assigned_user: [:broker, :broker_role, :organization], latest_assisted_property_post_agreement: [:assisted_by]])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.resale().id, PostSubType.property().id, true)
    end)
  end

  def posts_filter_query(params, broker \\ nil, is_owner \\ nil, only_active \\ nil) do
    page =
      case not is_nil(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 15
      end

    archived = if params["archived"] == "true", do: true, else: false

    query =
      ResalePropertyPost
      |> join(:inner, [r], b in Building, on: r.building_id == b.id)
      |> join(:inner, [r, b], p in Polygon, on: b.polygon_id == p.id)

    query =
      if not is_nil(broker) do
        # Filtering non-verified property post where we are having post restricted by owner
        start_time_unix = Time.get_start_time_in_unix(0)
        end_time_unix = Time.get_end_time_in_unix(0)

        non_verified_excluded_posts =
          ContactedResalePropertyPost
          |> where([crp], crp.count > 0 and crp.user_id != ^broker.id)
          |> where(
            [crp],
            ^start_time_unix <= fragment("ROUND(extract(epoch from ?))", crp.inserted_at) and
              ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", crp.inserted_at)
          )
          |> join(:inner, [crp], rpp in ResalePropertyPost, on: rpp.id == crp.post_id)
          |> where([crp, rpp], rpp.is_verified == false)
          |> group_by([crp, rpp], crp.post_id)
          |> select([crp, rrp], {crp.post_id, count(crp.post_id)})
          |> Repo.all()
          |> Enum.filter(fn {_post_id, count} -> count >= Posts.restriction_limit_for_unverified_property_per_day_by_owner() end)
          |> Enum.map(fn {post_id, _count} -> post_id end)

        query |> where([r], r.id not in ^non_verified_excluded_posts)
      else
        query
      end

    {param_lat, param_long} =
      if not is_nil(params["google_place_id"]) do
        google_session_token = Map.get(params, "google_session_token", "")

        place_details_response = GoogleMapsHelper.fetch_place_details(params["google_place_id"], google_session_token)

        {place_details_response.latitude, place_details_response.longitude}
      else
        if not is_nil(params["latitude"]) and not is_nil(params["longitude"]) do
          {longitude, latitude} = params |> BuildingHelper.process_geo_params()
          {latitude, longitude}
        else
          {nil, nil}
        end
      end

    query =
      if not is_nil(params["active_only"]) do
        if params["active_only"] == true do
          query |> where([r], fragment("? >= timezone('utc', NOW())", r.expires_in))
        else
          query
        end
      else
        query
      end

    query =
      if not is_nil(params["is_assisted"]),
        do: query |> where([r], r.is_assisted == ^params["is_assisted"]),
        else: query

    query =
      if not is_nil(params["property_uuid"]) do
        query |> where([r], r.uuid == ^params["property_uuid"])
      else
        query
      end

    query =
      if not is_nil(params["verified"]) do
        query |> where([r], r.is_verified == ^params["verified"])
      else
        query
      end

    query =
      if not is_nil(is_owner) do
        query =
          query
          |> join(:inner, [r, b, p], o in Owner, on: o.id == r.assigned_owner_id)
          |> where([r], r.uploader_type == "owner")

        if params["include_archived"] != true do
          query |> where([r], r.archived == ^archived)
        else
          query
        end
      else
        query
      end

    query =
      if not is_nil(params["parking"]),
        do: query |> where([r], r.parking == ^params["parking"]),
        else: query

    query =
      if not is_nil(params["city_id"]) do
        query |> where([r, b, p], p.city_id == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["locality_ids"]) do
        zones =
          Enum.reduce(params["locality_ids"], [], fn polygon_id, acc ->
            with %Polygon{} = polygon <- Polygon.fetch_from_id(polygon_id) do
              acc ++ [polygon.zone_id]
            else
              _ -> acc
            end
          end)

        all_polygons_in_zones = Polygon.fetch_all_polygons_ids(zones)
        query |> where([r, b], (not r.is_assisted and b.polygon_id in ^params["locality_ids"]) or (r.is_assisted and b.polygon_id in ^all_polygons_in_zones))
      else
        query
      end

    query =
      if not is_nil(params["building_ids"]) do
        query |> where([r, b], b.uuid in ^params["building_ids"])
      else
        query
      end

    query =
      if not is_nil(is_owner) and not is_nil(params["phone"]) do
        if not is_nil(params["country_code"]) do
          query |> where([r, b, p, o], o.phone_number == ^params["phone"] and o.country_code == ^params["country_code"])
        else
          query |> where([r, b, p, o], o.phone_number == ^params["phone"])
        end
      else
        query
      end

    query =
      if not is_nil(is_owner) and not is_nil(params["owner_name"]) do
        search_query = "%#{String.downcase(String.trim(params["owner_name"]))}%"
        query |> where([r, b, p, o], fragment("LOWER(?) LIKE ?", o.name, ^search_query))
      else
        query
      end

    query =
      if not is_nil(is_owner) and not is_nil(params["query"]) do
        search_query = "%#{String.downcase(String.trim(params["query"]))}%"

        query
        |> where([r, b, p, o], o.phone_number == ^params["query"] or fragment("LOWER(?) LIKE ?", o.name, ^search_query))
      else
        query
      end

    query =
      if not is_nil(params["start_date"]) and not is_nil(params["end_date"]) do
        start_date = if is_binary(params["start_date"]), do: String.to_integer(params["start_date"]), else: params["start_date"]

        {:ok, start_date_time} = DateTime.from_unix(start_date)
        end_date = if is_binary(params["end_date"]), do: String.to_integer(params["end_date"]), else: params["end_date"]
        {:ok, end_date_time} = DateTime.from_unix(end_date)
        query |> where([r], r.inserted_at >= ^start_date_time and r.inserted_at <= ^end_date_time)
      else
        query
      end

    query =
      if not is_nil(params["added_since_in_days"]) do
        added_since_in_days =
          if is_binary(params["added_since_in_days"]),
            do: String.to_integer(params["added_since_in_days"]),
            else: params["added_since_in_days"]

        if added_since_in_days >= 0 do
          today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day()
          starting_day = Timex.shift(today, days: -1 * added_since_in_days)
          query |> where([r], r.inserted_at >= ^starting_day)
        else
          query
        end
      else
        query
      end

    query =
      if not is_nil(params["source"]),
        do: query |> where([r], r.source == ^params["source"]),
        else: query

    query =
      if not is_nil(params["post_uuids"]),
        do: query |> where([r], r.uuid in ^params["post_uuids"]),
        else: query

    query =
      if not is_nil(params["is_offline"]) do
        query |> where([r], r.is_offline == ^params["is_offline"])
      else
        query
      end

    query =
      if not is_nil(params["configuration_type_ids"]),
        do: query |> where([r], r.configuration_type_id in ^params["configuration_type_ids"]),
        else: query

    query =
      if not is_nil(params["max_price"]),
        do: query |> where([r], r.price <= ^params["max_price"]),
        else: query

    query =
      if not is_nil(params["min_carpet_area"]),
        do: query |> where([r], r.carpet_area >= ^params["min_carpet_area"]),
        else: query

    query =
      if not is_nil(params["only_reported_posts"]) do
        query
        |> join(:inner, [r], rrp in ReportedResalePropertyPost, on: rrp.resale_property_id == r.id)
        |> where([r, ..., rrp], is_nil(rrp.refreshed_by_id))
      else
        query
      end

    query =
      if not is_nil(is_owner) and not is_nil(params["is_owner_broker"]) do
        if params["is_owner_broker"] == true do
          query
          |> join(:left, [r, b, p, o], c in Credential, on: c.phone_number == o.phone_number)
          |> where([r, b, p, o, c], o.is_broker == true or not is_nil(c.id))
        else
          query
          |> join(:left, [r, b, p, o], c in Credential, on: c.phone_number == o.phone_number)
          |> where([r, b, p, o, c], (o.is_broker == false or is_nil(o.is_broker)) and is_nil(c.id))
        end
      else
        query
      end

    query =
      if not is_nil(params["is_contacted_post"]) do
        if params["is_contacted_post"] == true do
          query
          |> join(:inner, [r, ...], rm in ResaleMatch, on: rm.resale_property_id == r.id)
          |> where([r, ..., rm], rm.already_contacted == true)
        else
          query
          |> join(:left, [r, ...], rm in ResaleMatch, on: rm.resale_property_id == r.id)
          |> where([r, ..., rm], is_nil(rm.id) or (not is_nil(rm.id) and rm.already_contacted == false))
        end
      else
        query
      end

    query =
      if not is_nil(params["has_matches"]) do
        if params["has_matches"] == true do
          query
          |> join(:inner, [r, ...], rmm in ResaleMatch, on: rmm.resale_property_id == r.id)
        else
          query
          |> join(:left, [r, ...], rmm in ResaleMatch, on: rmm.resale_property_id == r.id)
          |> where([r, ..., rmm], is_nil(rmm.id))
        end
      else
        query
      end

    query =
      if not is_nil(param_lat) and not is_nil(param_long) do
        query
        |> where(
          [r, b],
          (not r.is_assisted and fragment("ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), ?), ?)", b.location, ^param_lat, ^param_long, ^@srid, ^@default_radius)) or
            (r.is_assisted and fragment("ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), ?), ?)", b.location, ^param_lat, ^param_long, ^@srid, ^@assisted_default_radius))
        )
      else
        query
      end

    query =
      if not is_nil(params["agent_name"]) do
        search_query = "%#{String.downcase(String.trim(params["agent_name"]))}%"

        query
        |> join(:left, [r, ...], ec in EmployeeCredential, on: ec.id == r.employees_credentials_id)
        |> where([r, ..., ec], fragment("LOWER(?) LIKE ?", ec.name, ^search_query))
      else
        query
      end

    expires_in_query = query

    query =
      if not is_nil(params["filter_by_expiry"]) do
        cond do
          params["expiring_in"] == 0 ->
            query |> where([r], fragment("?::date = current_date", r.expires_in))

          params["expiring_in"] == 1 ->
            query |> where([r], fragment("?::date = current_date + INTERVAL '1 day'", r.expires_in))

          params["expiring_in"] == 2 ->
            query |> where([r], fragment("?::date = current_date + INTERVAL '2 day'", r.expires_in))

          params["expiring_in"] == 3 ->
            query |> where([r], fragment("?::date = current_date + INTERVAL '3 day'", r.expires_in))

          params["expiring_in"] == 4 ->
            query |> where([r], fragment("?::date > current_date + INTERVAL '3 day'", r.expires_in))

          params["expiring_in"] == -1 ->
            query |> where([r], fragment("?::date = current_date - INTERVAL '1 day'", r.expires_in))

          params["expiring_in"] == -2 ->
            query |> where([r], fragment("?::date = current_date - INTERVAL '2 day'", r.expires_in))

          params["expiring_in"] == -3 ->
            query |> where([r], fragment("?::date < current_date - INTERVAL '2 day'", r.expires_in))

          true ->
            if not is_nil(broker) do
              query |> where([r], fragment("? >= timezone('utc', NOW())", r.expires_in))
            else
              query
            end
        end
      else
        if not is_nil(only_active) and params["include_archived"] != true do
          query |> where([r], r.archived == ^false)
        else
          query
        end
      end

    query =
      if not is_nil(broker) do
        query |> where([r], r.archived == ^false)
      else
        query
      end

    query =
      if not is_nil(broker) do
        properties_to_skip =
          ReportedResalePropertyPost
          |> join(:inner, [rrp], c in Credential, on: c.id == rrp.reported_by_id)
          |> where([rrp, c], c.broker_id == ^broker.id)
          |> select([rrp, c], rrp.resale_property_id)
          |> Repo.all()

        query |> where([r], r.id not in ^properties_to_skip)
      else
        query
      end

    # Sorting first by Assisted
    query = query |> order_by([r], desc: r.is_assisted)

    query =
      if not is_nil(param_lat) and not is_nil(param_long) do
        query
        |> order_by(
          [r, b],
          fragment("? <-> ST_SetSRID(ST_MakePoint(?,?), ?)", b.location, ^param_lat, ^param_long, ^@srid)
        )
      else
        query
      end

    query =
      if not is_nil(params["added_on"]) and params["added_on"] == "desc" do
        query |> order_by([r], asc: r.inserted_at)
      else
        if not is_nil(params["added_on"]) do
          query |> order_by([r], desc: r.inserted_at)
        else
          query
        end
      end

    query =
      if not is_nil(params["price"]) and params["price"] == "desc" do
        query |> order_by([r], desc: r.price)
      else
        if not is_nil(params["price"]) do
          query |> order_by([r], asc: r.price)
        else
          query
        end
      end

    query =
      if not is_nil(broker) and not is_nil(broker.polygon_id) do
        query |> order_by([r, b], desc: b.polygon_id == ^broker.polygon_id)
      else
        query
      end

    query =
      if is_nil(params["latitude"]) and is_nil(params["longitude"]) and is_nil(params["added_on"]) and
           is_nil(params["price"]) and is_nil(broker) do
        query |> order_by([r], desc: r.inserted_at)
      else
        query
      end

    content_query =
      query
      |> limit(^size)
      |> offset(^((page - 1) * size))

    {query, content_query, page, size, expires_in_query}
  end

  def fetch_resale_posts(params, broker \\ nil, is_owner \\ nil, only_active \\ nil) do
    {query, content_query, page, size, expires_in_query} = ResalePropertyPost.posts_filter_query(params, broker, is_owner, only_active)

    posts =
      content_query
      |> preload([
        :archived_by_employees_credentials,
        :verified_by_employees_credentials,
        :edited_by_employees_credentials,
        :assigned_owner,
        :employees_credentials,
        :assigned_user,
        :archived_reason,
        :latest_assisted_property_post_agreement,
        latest_assisted_property_post_agreement: [:assisted_by],
        building: [:polygon],
        assigned_user: [:broker]
      ])
      |> Repo.all()
      |> Enum.map(fn post ->
        get_resale_post_details(post, broker, params)
      end)

    posts = add_contacted_details_for_broker(posts, broker)

    posts = add_shortlisted_details_for_broker(posts, broker)

    expiry_wise_count =
      if not is_nil(params["filter_by_expiry"]) do
        expires_in_query
        |> group_by([r], fragment("?::date", r.expires_in))
        |> select(
          [r],
          {fragment(
             "CASE WHEN (?::date - current_date) <= -3 THEN -3 WHEN (?::date - current_date) >= 4 THEN 4 ELSE  (?::date - current_date) END",
             r.expires_in,
             r.expires_in,
             r.expires_in
           ), count(r.id)}
        )
        |> Repo.all()
        |> Enum.reduce(%{}, fn data, acc ->
          if not is_nil(acc[elem(data, 0)]) do
            Map.put(acc, elem(data, 0), acc[elem(data, 0)] + elem(data, 1))
          else
            Map.put(acc, elem(data, 0), elem(data, 1))
          end
        end)
      else
        %{}
      end

    total_count = query |> distinct(:id) |> Repo.aggregate(:count, :id)
    has_more_posts = page < Float.ceil(total_count / size)

    {posts, total_count, has_more_posts, expiry_wise_count}
  end

  def fetch_resale_posts_count(params, broker \\ nil, is_owner \\ nil, only_active \\ nil) do
    {query, _content_query, _page, _size, _expires_in_query} = ResalePropertyPost.posts_filter_query(params, broker, is_owner, only_active)
    query |> distinct(:id) |> Repo.aggregate(:count, :id)
  end

  def add_contacted_details_for_broker(posts, nil), do: posts

  def add_contacted_details_for_broker(posts, broker) do
    post_ids = posts |> Enum.map(& &1.id)

    contacted_map =
      ContactedResalePropertyPost
      |> where([crpp], crpp.post_id in ^post_ids and crpp.user_id == ^broker.id and crpp.count > 0)
      |> Repo.all()
      |> Enum.reduce(%{}, fn crpp, acc ->
        Map.put(acc, crpp.post_id, crpp.updated_at)
      end)

    posts
    |> Enum.map(fn post ->
      post
      |> Map.put(:contacted_at, Time.naive_second_to_millisecond(contacted_map[post.id]))
      |> Map.put(:contacted_at_unix, contacted_map[post.id] |> Time.naive_to_epoch_in_sec())
    end)
  end

  def add_shortlisted_details_for_broker(posts, nil), do: posts

  def add_shortlisted_details_for_broker(posts, broker) do
    post_uuids = broker.shortlisted_resale_posts |> Enum.map(& &1["uuid"])

    shortlisted_map =
      broker.shortlisted_resale_posts
      |> Enum.reduce(%{}, fn shortlist, acc ->
        acc |> Map.put(shortlist["uuid"], shortlist["shortlisted_at"])
      end)

    posts
    |> Enum.map(fn post ->
      post
      |> Map.put(:is_shortlisted, Enum.member?(post_uuids, post[:uuid]))
      |> Map.put(:shortlisted_at, shortlisted_map[post[:uuid]])
    end)
  end

  def get_resale_post_details(post, broker, params \\ %{}) do
    [latitude, longitude] = (post.building.location |> Geo.JSON.encode!())["coordinates"]

    distance =
      if not is_nil(params["latitude"]) and not is_nil(params["longitude"]) do
        pivot_location = params |> BuildingHelper.process_geo_params()
        Distance.GreatCircle.distance({longitude, latitude}, pivot_location)
      else
        0
      end

    reported_data =
      if not is_nil(params["only_reported_posts"]) do
        ReportedResalePropertyPost.get_reported_resale_property_details(post.id)
      else
        %{}
      end

    building_info = %{
      id: post.building.id,
      uuid: post.building.uuid,
      name:
        if(not String.contains?(post.building.name, post.building.polygon.name),
          do: "#{post.building.name}, #{post.building.polygon.name}",
          else: post.building.name
        ),
      display_address: post.building.display_address,
      polygon_uuid: post.building.polygon.uuid,
      polygon_name: post.building.polygon.name,
      polygon_id: post.building.polygon.id,
      city_id: post.building.polygon.city_id,
      locality_id: post.building.locality_id,
      sub_locality_id: post.building.sub_locality_id,
      latitude: latitude,
      longitude: longitude
    }

    employees_credentials =
      if params["owner_as_employee_not_required"] == "true" do
        (not is_nil(post.employees_credentials) and
           %{
             name: post.employees_credentials.name,
             phone_number: post.employees_credentials.phone_number,
             employee_role_id: post.employees_credentials.employee_role_id
           }) || %{}
      else
        (not is_nil(post.assigned_owner) and
           %{
             name: post.assigned_owner.name,
             phone_number: post.assigned_owner.phone_number,
             employee_role_id: nil
           }) || %{}
      end

    archived_by_employees_credentials =
      (not is_nil(post.archived_by_employees_credentials) and
         %{
           name: post.archived_by_employees_credentials.name,
           phone_number: post.archived_by_employees_credentials.phone_number,
           employee_role_id: post.archived_by_employees_credentials.employee_role_id,
           last_archived_at: Time.naive_to_epoch(post.last_archived_at)
         }) || %{}

    verified_by_employees_credentials =
      (not is_nil(post.verified_by_employees_credentials) and
         %{
           name: post.verified_by_employees_credentials.name,
           phone_number: post.verified_by_employees_credentials.phone_number,
           employee_role_id: post.verified_by_employees_credentials.employee_role_id,
           last_verified_at: Time.naive_to_epoch(post.last_verified_at)
         }) || %{}

    edited_by_employees_credentials =
      (not is_nil(post.edited_by_employees_credentials) and
         %{
           name: post.edited_by_employees_credentials.name,
           phone_number: post.edited_by_employees_credentials.phone_number,
           employee_role_id: post.edited_by_employees_credentials.employee_role_id,
           last_edited_at: Time.naive_to_epoch(post.last_edited_at)
         }) || %{}

    cc =
      if not is_nil(post.assigned_owner) && not is_nil(post.assigned_owner.country_code),
        do: post.assigned_owner.country_code,
        else: "+91"

    {latest_assisted_property_post_agreement_details, is_assisted_property} = get_latest_assisted_property_post_agreement_details(post, not is_nil(broker))

    assigned_owner =
      if is_nil(broker) or not is_assisted_property do
        if not is_nil(post.assigned_owner) do
          %{
            id: post.assigned_owner.id,
            uuid: post.assigned_owner.uuid,
            name: post.assigned_owner.name,
            email: post.assigned_owner.email,
            phone_number: post.assigned_owner.phone_number,
            country_code: cc,
            is_broker_flag: post.assigned_owner.is_broker
          }
        else
          %{
            id: post.assigned_user.id,
            uuid: post.assigned_user.uuid,
            name: post.assigned_user.broker.name,
            email: nil,
            phone_number: post.assigned_user.phone_number,
            country_code: cc,
            is_broker_flag: true
          }
        end
      else
        %{}
      end

    similar_posts_count = get_similar_posts_count(post, broker, post.assigned_owner_id, is_assisted_property)

    %{
      post_type: "resale",
      post_sub_type: "property",
      title: "Resale Property",
      is_offline: post.is_offline,
      archived: post.archived,
      archived_reason: maybe_get_archived_reason(post.archived_reason),
      verified: post.is_verified,
      expires_in: Time.naive_second_to_millisecond(post.expires_in),
      expires_in_unix: post.expires_in |> Time.naive_to_epoch_in_sec(),
      inserted_at: Time.naive_second_to_millisecond(post.inserted_at),
      inserted_at_unix: post.inserted_at |> Time.naive_to_epoch_in_sec(),
      inserted_at_formatted: post.inserted_at |> Time.get_time_distance(),
      uploader_type: post.uploader_type,
      source: post.source,
      carpet_area: post.carpet_area,
      notes: post.notes,
      parking: post.parking,
      price: post.price,
      formatted_price: Utils.format_money(post.price),
      uuid: post.uuid,
      id: post.id,
      reported_data: reported_data,
      configuration_type_id: post.configuration_type_id,
      floor_type_id: post.floor_type_id,
      building: building_info,
      employees_credentials: employees_credentials,
      archived_by_employees_credentials: archived_by_employees_credentials,
      verified_by_employees_credentials: verified_by_employees_credentials,
      edited_by_employees_credentials: edited_by_employees_credentials,
      assigned_owner: assigned_owner,
      latest_assisted_property_post_agreement_details: latest_assisted_property_post_agreement_details,
      is_assisted: is_assisted_property,
      distance: distance,
      similar_posts_count: similar_posts_count
    }
  end

  def get_latest_assisted_property_post_agreement_details(post, is_broker) do
    latest_assisted_property_post_agreement = post.latest_assisted_property_post_agreement

    latest_assisted_property_post_agreement_assisted_by_details =
      if not is_nil(latest_assisted_property_post_agreement) and not is_nil(latest_assisted_property_post_agreement.assisted_by) do
        %{
          name: "Broker Network",
          phone_number: latest_assisted_property_post_agreement.assisted_by.phone_number,
          country_code: latest_assisted_property_post_agreement.assisted_by.country_code
        }
      else
        %{}
      end

    if not is_nil(latest_assisted_property_post_agreement) do
      documents = AssistedProperty.get_all_documents(latest_assisted_property_post_agreement.id, [AssistedProperty.property_photo_doc_type()])
      number_of_documents = length(documents)

      is_assisted_property =
        post.is_assisted and latest_assisted_property_post_agreement.is_active == true and
          latest_assisted_property_post_agreement.status == String.to_atom(AssistedProperty.assisted())

      app_details = %{
        assisted_by_details: latest_assisted_property_post_agreement_assisted_by_details,
        number_of_documents: number_of_documents,
        documents: documents
      }

      cond do
        not is_broker ->
          {Map.merge(app_details, %{
             uuid: latest_assisted_property_post_agreement.uuid,
             is_active: latest_assisted_property_post_agreement.is_active,
             status: latest_assisted_property_post_agreement.status
           }), is_assisted_property}

        is_assisted_property == true ->
          {app_details, is_assisted_property}

        true ->
          {%{}, is_assisted_property}
      end
    else
      {%{}, false}
    end
  end

  def get_similar_posts_count(_post, _broker, assigned_owner_id, is_assisted_property) when is_nil(assigned_owner_id) or is_assisted_property == true, do: 0

  def get_similar_posts_count(post, broker, _assigned_owner_id, _is_assisted_property) do
    get_similar_posts_query(post, broker) |> Repo.aggregate(:count, :id)
  end

  def get_similar_posts_query(post, broker) do
    properties_to_skip =
      if not is_nil(broker) do
        ReportedResalePropertyPost
        |> join(:inner, [rrp], c in Credential, on: c.id == rrp.reported_by_id)
        |> where([rrp, c], c.broker_id == ^broker.id)
        |> select([rrp, c], rrp.resale_property_id)
        |> Repo.all()
      else
        []
      end

    ResalePropertyPost
    |> where([rpp], rpp.archived == ^false)
    |> where([rpp], rpp.id not in ^properties_to_skip)
    |> where([rpp], rpp.building_id == ^post.building_id)
    |> where([rpp], rpp.configuration_type_id == ^post.configuration_type_id)
    |> where([rpp], rpp.uuid != ^post.uuid)
    |> where([rpp], not is_nil(rpp.assigned_owner_id))
    |> order_by([rpp], desc: rpp.inserted_at)
    |> preload([
      :archived_by_employees_credentials,
      :verified_by_employees_credentials,
      :edited_by_employees_credentials,
      :assigned_owner,
      :employees_credentials,
      :assigned_user,
      :archived_reason,
      :latest_assisted_property_post_agreement,
      latest_assisted_property_post_agreement: [:assisted_by],
      building: [:polygon],
      assigned_user: [:broker]
    ])
  end

  def fetch_shortlisted_owner_posts(broker) do
    post_uuids = broker.shortlisted_resale_posts |> Enum.map(& &1["uuid"])

    {posts, _total_count, _has_more_posts, _expiry_wise_count} = fetch_resale_posts(%{"post_uuids" => post_uuids, "size" => "100"}, broker)

    posts
  end

  defp format_changeset_result(%Ecto.Changeset{valid?: true} = changeset), do: {:ok, changeset}
  defp format_changeset_result(%Ecto.Changeset{valid?: false} = changeset), do: {:error, changeset}

  def generate_shareable_post_image_url(post_uuid, user_id) do
    user = Accounts.get_credential!(user_id) |> Repo.preload([:broker, :organization])

    post =
      ResalePropertyPost
      |> where([rpp], rpp.uuid == ^post_uuid)
      |> preload([:configuration_type, :building])
      |> Repo.one()

    case post do
      nil ->
        {:error, "Post Not Found"}

      post ->
        broker_name = if not is_nil(user.broker), do: user.broker.name, else: ""

        # Converting the image to 60 X 60 to fit in html
        broker_profile_image =
          if(not is_nil(user.broker.profile_image),
            do: S3Helper.get_imgix_url(user.broker.profile_image["url"]),
            else: S3Helper.get_imgix_url("profile_avatar.png")
          ) <> "?auto=format&w=50&h=50"

        organization_name = if not is_nil(user.organization), do: user.organization.name, else: ""
        broker_phone_number = if not is_nil(user.broker), do: "#{user.country_code}-#{user.phone_number}", else: ""

        params = %{
          building_name: post.building.name,
          price: Utils.format_money(post.price),
          carpet_area: "#{post.carpet_area} sqft",
          parking: "#{post.parking} Parking",
          configuration_type: post.configuration_type.name,
          building_display_address: post.building.display_address,
          notes: post.notes,
          broker_name: broker_name,
          broker_phone_number: broker_phone_number,
          broker_profile_image: broker_profile_image,
          organization_name: organization_name
        }

        image_url =
          HtmlHelper.generate_html(params, BnApisWeb.PostView, "shareable_resale_post.html")
          |> HtmlHelper.generate_image_url_from_html(@s3_prefix_reshareable_image)

        case image_url do
          nil -> {:error, "Image is not created"}
          image_url -> {:ok, image_url}
        end
    end
  end

  defp maybe_get_archived_reason(%Ecto.Association.NotLoaded{}), do: nil
  defp maybe_get_archived_reason(nil), do: nil
  defp maybe_get_archived_reason(archived_reason), do: archived_reason.name
end
