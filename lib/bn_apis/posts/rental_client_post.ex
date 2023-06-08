defmodule BnApis.Posts.RentalClientPost do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Buildings.Building
  alias BnApis.Buildings
  alias BnApis.Accounts.Credential
  alias BnApis.Posts.{RentalPropertyPost, RentalClientPost, RentalMatch}
  alias BnApis.Repo
  alias BnApis.Helpers.Time
  alias BnApis.Reasons.Reason

  schema "rental_client_posts" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :name, :string
    field :is_bachelor, :boolean, default: false
    field :max_rent, :integer
    field :notes, :string
    field :configuration_type_ids, {:array, :integer}
    field :furnishing_type_ids, {:array, :integer}
    field :building_ids, {:array, :integer}

    field :archived, :boolean, default: false
    field :expires_in, :naive_datetime
    field :updation_time, :naive_datetime
    field :test_post, :boolean, default: false
    field :auto_expired_read, :boolean, default: false

    belongs_to :archived_by, Credential
    belongs_to :refreshed_by, Credential
    belongs_to :archived_reason, Reason

    belongs_to :user, Credential
    belongs_to :assigned_user, Credential

    timestamps()
  end

  @doc """
  Form Details:
  Config - Studio/1BHK/2BHK/3BHK/4+BHK - Multi Select - Mandatory
  Is Bachelor - Yes/No - Mandatory
  Preferred Furnishing - Unfurnished/Semi/Full - Multi Select - Mandatory
  Max Rent(Budget)- Optional
  Building(s)  - Search and Select - Multi Select - Mandatory
  Notes - Open Text Field - Optional
  Assigned To - Single Select from a list of teammates - Mandatory - Defaults to Current User
  """
  @fields [
    :name,
    :max_rent,
    :is_bachelor,
    :notes,
    :assigned_user_id,
    :building_ids,
    :configuration_type_ids,
    :furnishing_type_ids,
    :user_id,
    :archived,
    :expires_in,
    :archived_by_id,
    :refreshed_by_id,
    :updation_time,
    :archived_reason_id,
    :test_post
  ]
  @required_fields [:building_ids, :configuration_type_ids, :furnishing_type_ids, :is_bachelor, :assigned_user_id]

  def changeset(rental_client_post, attrs \\ %{}) do
    rental_client_post
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:assigned_user_id)
  end

  def get_post(post_id, add_building_info \\ true) do
    post =
      RentalClientPost
      |> where([rcp], rcp.id == ^post_id)
      |> preload([
        :archived_reason,
        archived_by: [:broker],
        refreshed_by: [:broker],
        assigned_user: [:broker],
        user: [:broker]
      ])
      |> Repo.all()
      |> Enum.map(fn rcp ->
        archived_by =
          if not is_nil(rcp.archived_by) do
            %{
              "id" => rcp.archived_by.broker.id,
              "name" => rcp.archived_by.broker.name,
              "phone_number" => rcp.archived_by.phone_number
            }
          else
            nil
          end

        refreshed_by =
          if not is_nil(rcp.refreshed_by) do
            %{
              "id" => rcp.refreshed_by.broker.id,
              "name" => rcp.refreshed_by.broker.name,
              "phone_number" => rcp.refreshed_by.phone_number
            }
          else
            nil
          end

        assigned_user =
          if not is_nil(rcp.assigned_user) do
            %{
              "id" => rcp.assigned_user.broker.id,
              "name" => rcp.assigned_user.broker.name,
              "phone_number" => rcp.assigned_user.phone_number
            }
          else
            nil
          end

        user =
          if not is_nil(rcp.assigned_user) do
            %{
              "id" => rcp.user.broker.id,
              "name" => rcp.user.broker.name,
              "phone_number" => rcp.user.phone_number
            }
          else
            nil
          end

        %{
          "id" => rcp.id,
          "is_bachelor" => rcp.is_bachelor,
          "name" => rcp.name,
          "max_rent" => rcp.max_rent,
          "notes" => rcp.notes,
          "uuid" => rcp.uuid,
          "assigned_user_id" => rcp.assigned_user_id,
          "configuration_type_ids" => rcp.configuration_type_ids,
          "furnishing_type_ids" => rcp.furnishing_type_ids,
          "building_ids" => rcp.building_ids,
          "expires_in" => rcp.expires_in |> Time.naive_to_epoch(),
          "test_post" => rcp.test_post,
          "archived" => rcp.archived,
          "archived_reason" => if(not is_nil(rcp.archived_reason), do: rcp.archived_reason.name, else: nil),
          "archived_by" => archived_by,
          "refreshed_by" => refreshed_by,
          "assigned_user" => assigned_user,
          "user" => user,
          "inserted_at" => rcp.inserted_at
        }
      end)
      |> List.last()

    if add_building_info do
      put_in(post, ["building_names"], Building.get_building_names(post["building_ids"]))
    else
      post
    end
  end

  def mark_post_matches_irrelevant(user_id, rental_client_ids) do
    RentalMatch
    |> join(:inner, [rm], rpp in RentalPropertyPost, on: rm.rental_property_id == rpp.id and rpp.assigned_user_id == ^user_id)
    |> where([rm], rm.rental_client_id in ^rental_client_ids)
    |> update(set: [is_relevant: false])
    |> Repo.update_all([])
  end

  alias BnApis.Posts.MatchReadStatus

  def mark_post_matches_as_read(user_id, rental_client_ids) do
    RentalMatch
    |> where([rm], rm.rental_client_id in ^rental_client_ids)
    |> Repo.all()
    |> Enum.map(fn rm ->
      %{
        read: true,
        user_id: user_id,
        rental_matches_id: rm.id,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
    |> (&Repo.insert_all(MatchReadStatus, &1, on_conflict: :nothing)).()
  end

  def fetch_duplicate_posts(params) do
    {:ok, building_ids} = Buildings.get_ids_from_uids(params["building_ids"])

    RentalClientPost
    |> where(
      [rcp],
      rcp.assigned_user_id == ^params["assigned_user_id"] and
        rcp.max_rent == ^params["max_rent"] and
        rcp.is_bachelor == ^params["is_bachelor"] and
        fragment("? >= timezone('utc', NOW())", rcp.expires_in)
    )
    |> Repo.all()
    |> Enum.filter(
      &(length(&1.configuration_type_ids -- params["configuration_type_ids"]) == 0 and
          length(&1.building_ids -- building_ids) == 0 and
          length(&1.furnishing_type_ids -- params["furnishing_type_ids"]) == 0)
    )
  end

  def check_duplicate_posts_count(params) do
    if params |> fetch_duplicate_posts() |> length() > 0,
      do: {:error, "Post with same params already exists"},
      else: {:ok, ""}
  end

  def fetch_unmatched_posts do
    {start_time, end_time} = Time.get_day_beginnning_and_end_time()

    RentalClientPost
    |> join(:inner, [rcp], cred in Credential, on: rcp.assigned_user_id == cred.id)
    |> join(:inner, [rcp, cred], rm in RentalMatch, on: not (rm.rental_client_id == rcp.id) and not is_nil(cred.organization_id))
    |> where([rcp, cred, _], rcp.inserted_at >= ^start_time and rcp.inserted_at <= ^end_time)
    |> select([rcp, cred, _], %{
      id: rcp.id,
      organization_id: cred.organization_id
    })
    |> Repo.all()
  end

  def fetch_soon_to_expire_posts do
    RentalClientPost
    |> join(:inner, [rcp], cred in Credential, on: rcp.assigned_user_id == cred.id)
    |> where([rcp, cred], cred.active == true and not is_nil(cred.fcm_id))
    |> where([rcp, cred], fragment("?::date = current_date", rcp.expires_in))
    |> where([rcp, cred], rcp.archived == false)
    |> select([rcp, cred], %{
      fcm_id: cred.fcm_id,
      notification_platform: cred.notification_platform,
      expires_in: rcp.expires_in,
      post_uuid: rcp.uuid,
      user_id: cred.id
    })
    |> Repo.all()
  end

  alias BnApis.Posts.{PostType, PostSubType}
  alias BnApis.Posts.MatchHelper

  def fetch_posts(user_id) do
    RentalClientPost
    |> where([rcp], rcp.assigned_user_id == ^user_id)
    |> Repo.all()
  end

  def fetch_all_posts(organization_id, user_id) do
    RentalClientPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        fragment("? >= timezone('utc', NOW())", rp.expires_in)
    )
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id, true)
    end)
  end

  def team_posts(organization_id, user_id) do
    RentalClientPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where(
      [rp, cred],
      cred.organization_id == ^organization_id and
        cred.active == true and
        rp.archived == false and
        fragment("? >= timezone('utc', NOW())", rp.expires_in) and
        rp.assigned_user_id != ^user_id
    )
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id, true)
    end)
  end

  def fetch_org_user_posts(organization_id, user_id) do
    RentalClientPost
    |> join(:inner, [rp], cred in Credential, on: rp.assigned_user_id == cred.id)
    |> where([rp, cred], cred.organization_id == ^organization_id and cred.active == true)
    |> where([rp, cred], rp.assigned_user_id == ^user_id)
    |> Repo.all()
  end

  # send only auto expired posts
  def fetch_all_expired_posts(organization_id, user_id) do
    RentalClientPost
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
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id, true)
    end)
  end

  def fetch_all_unread_expired_posts(organization_id, user_id) do
    RentalClientPost
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
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id, true)
    end)
  end

  def mark_unread_expired_posts_as_read(user_id) do
    RentalClientPost
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
    RentalClientPost
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
    |> preload(assigned_user: [:broker, :broker_role, :organization])
    |> Repo.all()
    |> Enum.map(fn rp ->
      rp |> MatchHelper.structured_post_keys(user_id, PostType.rent().id, PostSubType.client().id, true)
    end)
  end

  def posts_filter_query(params) do
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

    query = RentalClientPost

    content_query =
      query
      |> limit(^size)
      |> order_by([r], desc: r.inserted_at)
      |> offset(^((page - 1) * size))

    {query, content_query, page, size}
  end

  def fetch_rental_posts(params) do
    {query, content_query, page, size} = RentalClientPost.posts_filter_query(params)

    posts =
      content_query
      |> preload([:assigned_user, assigned_user: [:broker]])
      |> Repo.all()
      |> Enum.map(fn r -> get_post(r.id) end)

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_posts = page < Float.ceil(total_count / size)
    {posts, total_count, has_more_posts}
  end
end
