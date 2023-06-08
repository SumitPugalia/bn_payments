defmodule BnApisWeb.V1.PostController do
  use BnApisWeb, :controller

  alias BnApis.Posts
  alias BnApis.Accounts
  alias BnApis.Buildings
  alias BnApis.Helpers.Connection
  alias BnApis.Accounts.BlockedUser
  alias BnApis.Posts.{PostType, PostSubType, MatchHelper}
  alias BnApis.Posts.{RentalPropertyPost, ResalePropertyPost}

  action_fallback BnApisWeb.FallbackController

  @post_type_rent_id PostType.rent().id
  @post_type_resale_id PostType.resale().id
  @post_subtype_property_id PostSubType.property().id
  @post_subtype_client_id PostSubType.client().id

  # @post_per_page 10

  @doc """
  WHEN COMMIT = false
  """
  def create_post(
        conn,
        params = %{
          "building_id" => building_id,
          "configuration_type_id" => configuration_type_id,
          "commit" => "false",
          "post_type" => post_type,
          "post_sub_type" => "property"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_sub_type = params["post_sub_type"]
    {:ok, a_user_id} = Accounts.uuid_to_id(params["assigned_user_id"])
    blocked_users = BlockedUser.fetch_blocked_users(a_user_id)
    is_test_post = Accounts.is_test_post?(logged_in_user.user_id, a_user_id)

    method_name = String.to_atom("fetch_count_#{post_type}_#{post_sub_type}_post_matches")

    with {:ok, brokers_count, matches_count} <-
           apply(Posts, method_name, [
             a_user_id,
             configuration_type_id,
             building_id,
             params["is_bachelor_allowed"],
             blocked_users,
             is_test_post,
             params
           ]) do
      conn
      |> put_status(:ok)
      |> json(%{brokers_count: brokers_count, matches_count: matches_count, post_details: post_details(params)})
    end
  end

  def create_post(
        conn,
        params = %{
          "building_ids" => building_ids,
          "configuration_type_ids" => configuration_type_ids,
          "commit" => "false",
          "post_type" => post_type,
          "post_sub_type" => "client"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_sub_type = params["post_sub_type"]
    {:ok, a_user_id} = Accounts.uuid_to_id(params["assigned_user_id"])
    blocked_users = BlockedUser.fetch_blocked_users(a_user_id)
    is_test_post = Accounts.is_test_post?(logged_in_user.user_id, a_user_id)

    building_ids = if building_ids == "", do: [], else: building_ids |> Poison.decode!() |> Enum.uniq()
    configuration_type_ids = if configuration_type_ids == "", do: [], else: configuration_type_ids |> Poison.decode!()

    furnishing_type_ids =
      if is_nil(params["furnishing_type_ids"]) or params["furnishing_type_ids"] == "",
        do: [],
        else: params["furnishing_type_ids"] |> Poison.decode!()

    floor_type_ids =
      if is_nil(params["floor_type_ids"]) or params["floor_type_ids"] == "",
        do: [],
        else: params["floor_type_ids"] |> Poison.decode!()

    params =
      params
      |> Map.merge(%{
        "furnishing_type_ids" => furnishing_type_ids,
        "floor_type_ids" => floor_type_ids,
        "configuration_type_ids" => configuration_type_ids,
        "building_ids" => building_ids
      })

    method_name = String.to_atom("fetch_count_#{post_type}_#{post_sub_type}_post_matches")

    with {:ok, brokers_count, matches_count} <-
           apply(Posts, method_name, [
             a_user_id,
             configuration_type_ids,
             building_ids,
             params["is_bachelor"],
             blocked_users,
             is_test_post,
             params
           ]) do
      conn
      |> put_status(:ok)
      |> json(%{brokers_count: brokers_count, matches_count: matches_count, post_details: post_details(params)})
    end
  end

  def post_details(params) do
    building_names = get_building_names(params["building_ids"] || [params["building_id"]])

    post_params = %{
      price: params["price"],
      max_budget: params["max_budget"],
      rent_expected: params["rent_expected"],
      max_rent: params["max_rent"],
      parking: params["parking"],
      min_parking: params["min_parking"],
      carpet_area: params["carpet_area"],
      min_carpet_area: params["min_carpet_area"],
      furnishing_type_ids: params["furnishing_type_ids"],
      furnishing_type_id: params["furnishing_type_id"],
      floor_type_ids: params["floor_type_ids"],
      floor_type_id: params["floor_type_id"],
      is_bachelor: params["is_bachelor"],
      is_bachelor_allowed: params["is_bachelor_allowed"],
      configuration_type_ids: params["configuration_type_ids"],
      configuration_type_id: params["configuration_type_id"],
      building_names: building_names
    }

    post_type_id = if params["post_type"] == "rent", do: @post_type_rent_id, else: @post_type_resale_id

    post_subtype_id = if params["post_sub_type"] == "client", do: @post_subtype_client_id, else: @post_subtype_property_id

    info = get_post_info(post_params, post_type_id, post_subtype_id)
    sub_info = MatchHelper.create_post_sub_info(post_params, post_type_id)

    assigned_user = Accounts.get_credential_by_uuid(params["assigned_user_id"])

    %{
      info: info,
      sub_info: sub_info,
      title: MatchHelper.post_title(post_type_id, post_subtype_id),
      notes: params["notes"],
      assigned_to: MatchHelper.get_assigned_user(assigned_user)
    }
  end

  defp get_building_names(building_ids) do
    {:ok, buildings} = Buildings.get_building_data_from_ids(building_ids)
    buildings |> Enum.map(& &1.building_name)
  end

  defp get_post_info(params, post_type_id, post_subtype_id) do
    if post_subtype_id == PostSubType.property().id do
      MatchHelper.property_info(
        hd(params[:building_names]),
        params[:configuration_type_id],
        PostType.get_by_id(post_type_id).name
      )
    else
      MatchHelper.client_info(
        params[:building_names],
        params[:configuration_type_ids],
        PostType.get_by_id(post_type_id).name
      )
    end
  end

  @doc """
  Given a post_uuid,
  Gives all post matches (Rent -> Client <-> Property) and vice-versa.
  Returns matches with different brokers(limited to @match_per_broker for a broker)
  """
  def post_matches(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type,
          "post_sub_type" => post_sub_type
          # "page" => page,
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    method_name = String.to_atom("fetch_#{post_type}_#{post_sub_type}_post_matches_v1")

    with {:ok, {post_in_context, matches, total_matches_count, has_more_matches}} <-
           apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, page]) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches || [],
        has_more_matches: has_more_matches,
        total_matches_count: total_matches_count,
        post_in_context: post_in_context
      })
    end
  end

  def fetch_owner_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {posts, total_count, has_more_posts} <- Posts.fetch_owner_posts_for_broker(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_posts: has_more_posts
      })
    end
  end

  def fetch_shortlisted_owner_posts(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {posts} <- Posts.fetch_shortlisted_owner_posts(logged_in_user) do
      conn
      |> put_status(:ok)
      |> json(%{posts: posts})
    end
  end

  def shortlist_owner_post(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("shortlist_#{post_type}_property_owner_post")
    addition = not (params["addition"] == "false")

    case apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, post_type, addition]) do
      {:ok, message} ->
        conn
        |> put_status(:ok)
        |> json(%{message: message})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: error_message})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  def mark_owner_post_contacted(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)
    post_type = post_type |> String.downcase()
    method_name = String.to_atom("mark_#{post_type}_property_owner_post_contacted")

    case apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, post_type, true]) do
      {:ok, message} ->
        conn
        |> put_status(:ok)
        |> json(%{message: message})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: error_message})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  @doc """
    Deleted Posts are marked as `archived` in posts specifically
    Auto-expired Posts are timed expired based on `expires_in`
  """
  def fetch_expired_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    with {:ok, assigned_to_me_posts, _assigned_to_others_posts, total_posts_count, has_more_posts} <-
           Posts.fetch_expired_posts(organization_id, user_id, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        assigned_to_me: assigned_to_me_posts || [],
        has_more_posts: has_more_posts,
        total_posts_count: total_posts_count
      })
    end
  end

  def fetch_unread_expired_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    with {:ok, posts, has_more_posts} <- Posts.fetch_unread_expired_posts(organization_id, user_id, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts || [],
        has_more_posts: has_more_posts
      })
    end
  end

  def fetch_unread_expired_posts_count(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    with {:ok, count} <- Posts.unread_expired_posts_count(organization_id, user_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        count: count
      })
    end
  end

  @doc """
  Paginated API.
  To fetch further pages, client will have to send last id received.
  Posts will be served in the order they were created.

  Response will be in this format

  returns {
    "posts" : {
      "assigned_to_me" : [] <Array of posts assigned to me>,
      "assigned_to_others" : [] <Array of posts assigned to others>,
    },
    "more" : true/false - <Flag indicating whether server has more posts to serve>
  }
  """
  def team_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    with {:ok, posts, has_more_posts} <- Posts.team_posts(organization_id, user_id, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts || [],
        has_more_posts: has_more_posts
      })
    end
  end

  def mark_all_expired_as_read(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_id = logged_in_user[:user_id]

    with {:ok, message} <- Posts.mark_all_expired_as_read(user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  def report_post(conn, %{
        "post_type" => post_type,
        "post_sub_type" => post_sub_type,
        "post_uuid" => post_uuid,
        "reason_id" => reason_id
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_type = post_type |> String.downcase()
    post_sub_type = post_sub_type |> String.downcase()

    method_name = String.to_atom("report_#{post_type}_#{post_sub_type}_post")

    with {:ok, _changeset} <- apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, reason_id]) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully Reported"})
    end
  end

  def list_similar_posts(conn, %{
        "post_type" => post_type,
        "post_uuid" => post_uuid
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_id = logged_in_user[:user_id]
    response = Posts.list_similar_posts_for_broker(post_type, post_uuid, user_id)

    conn
    |> put_status(:ok)
    |> json(%{response: response})
  end

  @doc """
    Requires:
      {
        post_type: "rent/resale",
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      }
  """
  def generate_shareable_post_image_url(
        conn,
        _params = %{
          "post_type" => post_type,
          "post_uuid" => post_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_module =
      case post_type do
        "rent" -> RentalPropertyPost
        "resale" -> ResalePropertyPost
      end

    case post_module.generate_shareable_post_image_url(post_uuid, logged_in_user.user_id) do
      {:ok, image_url} ->
        conn |> put_status(:ok) |> json(%{image_url: image_url})

      {:error, error_message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: error_message})
    end
  end
end
