defmodule BnApisWeb.PostController do
  use BnApisWeb, :controller

  alias BnApis.Posts
  alias BnApis.Posts.{RentalClientPost, RentalPropertyPost, ResaleClientPost, ResalePropertyPost, MatchHelper}

  alias BnApis.ProcessPostMatchWorker
  alias BnApis.Organizations.BrokerRole
  alias BnApis.{Accounts, Repo}
  alias BnApis.Helpers.Connection
  alias BnApis.Accounts.{BlockedUser, EmployeeRole}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.owner_supply_operations().id
         ]
       ]
       when action in [:refresh_reported_owner_post, :archive_owner_post, :refresh_owner_post]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.owner_supply_operations().id,
           EmployeeRole.assisted_admin().id
         ]
       ]
       when action in [:fetch_owner_posts]

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

  def create(conn, %{"rental_property_post" => rental_property_post_params}) do
    with {:ok, %RentalPropertyPost{} = rental_property_post} <-
           Posts.create_rental_property_post(rental_property_post_params) do
      conn
      |> put_status(:created)
      # |> put_resp_header("location", Routes.post_path(conn, :show, rental_property_post))
      |> render("show.json", rental_property_post: rental_property_post)
    end
  end

  def show(conn, %{"id" => id}) do
    rental_property_post = Posts.get_rental_property_post!(id)
    render(conn, "show.json", rental_property_post: rental_property_post)
  end

  @doc """
  """
  def create_post(
        conn,
        params = %{
          "is_bachelor" => _is_bachelor,
          # "max_rent" => max_rent, OPTIONAL
          # "notes" => notes, OPTIONAL
          "assigned_user_id" => assigned_user_id,
          "building_ids" => building_ids,
          "configuration_type_ids" => configuration_type_ids,
          "furnishing_type_ids" => furnishing_type_ids,
          "commit" => "true",
          "post_type" => "rent",
          "post_sub_type" => "client"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]

    building_ids = if building_ids == "", do: [], else: building_ids |> Poison.decode!() |> Enum.uniq()
    configuration_type_ids = if configuration_type_ids == "", do: [], else: configuration_type_ids |> Poison.decode!()
    furnishing_type_ids = if furnishing_type_ids == "", do: [], else: furnishing_type_ids |> Poison.decode!()

    with {:ok, a_user_id} <- Accounts.uuid_to_id(assigned_user_id),
         params =
           params
           |> Map.merge(%{
             "user_id" => logged_in_user.user_id,
             "assigned_user_id" => a_user_id,
             "building_ids" => building_ids,
             "configuration_type_ids" => configuration_type_ids,
             "furnishing_type_ids" => furnishing_type_ids,
             "test_post" => Accounts.is_test_post?(logged_in_user.user_id, a_user_id)
           }),
         {:ok, %RentalClientPost{} = rental_client_post} <- Posts.create_rental_client(params) do
      blocked_users = BlockedUser.fetch_blocked_users(a_user_id)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        rental_client_post.id,
        blocked_users,
        [],
        rental_client_post.test_post
      )

      rental_client_post = Repo.get_by(RentalClientPost, id: rental_client_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{rental_client_post.uuid}"})
    end
  end

  def create_post(
        conn,
        params = %{
          "is_bachelor_allowed" => _is_bachelor_allowed,
          "rent_expected" => _rent_expected,
          # "notes" => notes, OPTIONAL
          "assigned_user_id" => assigned_user_id,
          "building_id" => _building_id,
          "configuration_type_id" => _configuration_type_id,
          "furnishing_type_id" => _furnishing_type_id,
          "commit" => "true",
          "post_type" => "rent",
          "post_sub_type" => "property"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]

    with {:ok, a_user_id} <- Accounts.uuid_to_id(assigned_user_id),
         params =
           params
           |> Map.merge(%{
             "user_id" => logged_in_user.user_id,
             "assigned_user_id" => a_user_id,
             "test_post" => Accounts.is_test_post?(logged_in_user.user_id, a_user_id)
           }),
         {:ok, %RentalPropertyPost{} = rental_property_post} <- Posts.create_rental_property(params) do
      blocked_users = BlockedUser.fetch_blocked_users(a_user_id)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        rental_property_post.id,
        blocked_users,
        [],
        rental_property_post.test_post
      )

      rental_property_post = Repo.get_by(RentalPropertyPost, id: rental_property_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{rental_property_post.uuid}"})
    end
  end

  def create_post(
        conn,
        params = %{
          "building_ids" => building_ids,
          "max_budget" => _max_budget,
          "min_carpet_area" => _min_carpet_area,
          "min_parking" => _min_parking,
          # "notes" => notes, OPTIONAL
          "assigned_user_id" => assigned_user_id,
          "configuration_type_ids" => configuration_type_ids,
          "floor_type_ids" => floor_type_ids,
          "commit" => "true",
          "post_type" => "resale",
          "post_sub_type" => "client"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]

    building_ids = if building_ids == "", do: [], else: building_ids |> Poison.decode!() |> Enum.uniq()
    configuration_type_ids = if configuration_type_ids == "", do: [], else: configuration_type_ids |> Poison.decode!()
    floor_type_ids = if floor_type_ids == "", do: [], else: floor_type_ids |> Poison.decode!()

    with {:ok, a_user_id} <- Accounts.uuid_to_id(assigned_user_id),
         params =
           params
           |> Map.merge(%{
             "user_id" => logged_in_user.user_id,
             "assigned_user_id" => a_user_id,
             "building_ids" => building_ids,
             "configuration_type_ids" => configuration_type_ids,
             "floor_type_ids" => floor_type_ids,
             "test_post" => Accounts.is_test_post?(logged_in_user.user_id, a_user_id)
           }),
         {:ok, %ResaleClientPost{} = resale_client_post} <- Posts.create_resale_client(params) do
      blocked_users = BlockedUser.fetch_blocked_users(a_user_id)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        resale_client_post.id,
        blocked_users,
        [],
        resale_client_post.test_post
      )

      resale_client_post = Repo.get_by(ResaleClientPost, id: resale_client_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{resale_client_post.uuid}"})
    end
  end

  def create_post(
        conn,
        params = %{
          "price" => _price,
          "carpet_area" => _carpet_area,
          "parking" => _parking,
          # "notes" => notes, OPTIONAL
          "building_id" => _building_id,
          "assigned_user_id" => assigned_user_id,
          "configuration_type_id" => _configuration_type_id,
          "floor_type_id" => _floor_type_id,
          "commit" => "true",
          "post_type" => "resale",
          "post_sub_type" => "property"
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]

    with {:ok, a_user_id} <- Accounts.uuid_to_id(assigned_user_id),
         params =
           params
           |> Map.merge(%{
             "user_id" => logged_in_user.user_id,
             "assigned_user_id" => a_user_id,
             "test_post" => Accounts.is_test_post?(logged_in_user.user_id, a_user_id)
           }),
         {:ok, %ResalePropertyPost{} = resale_property_post} <- Posts.create_resale_property(params) do
      blocked_users = BlockedUser.fetch_blocked_users(a_user_id)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        resale_property_post.id,
        blocked_users,
        [],
        resale_property_post.test_post
      )

      resale_property_post = Repo.get_by(ResalePropertyPost, id: resale_property_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{resale_property_post.uuid}"})
    end
  end

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
      |> json(%{brokers_count: brokers_count, matches_count: matches_count})
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
        "floor_type_ids" => floor_type_ids
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
      |> json(%{brokers_count: brokers_count, matches_count: matches_count})
    end
  end

  def create_owner_post(
        conn,
        params = %{
          "post_type" => "rent",
          "building_id" => _building_id
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if not Enum.member?(
         [EmployeeRole.super().id, EmployeeRole.owner_supply_admin().id, EmployeeRole.owner_supply_operations().id],
         logged_in_user.employee_role_id
       ) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Either Owner Supply Admin or Operations is allowed to create"})
    else
      post_type = params["post_type"]
      post_sub_type = "property"

      params =
        params
        |> Map.put("uploader_type", "owner")
        |> Map.put("employees_credentials_id", logged_in_user.user_id)
        |> Map.put("test_post", false)

      {:ok, rental_property_post} = Posts.create_rental_property(params)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        rental_property_post.id,
        [],
        [],
        rental_property_post.test_post
      )

      rental_property_post = Repo.get_by(RentalPropertyPost, id: rental_property_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{rental_property_post.uuid}"})
    end
  end

  def create_owner_post(
        conn,
        params = %{
          "post_type" => "resale",
          "building_id" => _building_id
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if not Enum.member?(
         [EmployeeRole.super().id, EmployeeRole.owner_supply_admin().id, EmployeeRole.owner_supply_operations().id],
         logged_in_user.employee_role_id
       ) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Either Owner Supply Admin or Operations is allowed to create"})
    else
      post_type = params["post_type"]
      post_sub_type = "property"

      params =
        params
        |> Map.put("uploader_type", "owner")
        |> Map.put("employees_credentials_id", logged_in_user.user_id)
        |> Map.put("test_post", false)

      {:ok, resale_property_post} = Posts.create_resale_property(params)

      ProcessPostMatchWorker.perform(
        post_type,
        post_sub_type,
        resale_property_post.id,
        [],
        [],
        resale_property_post.test_post
      )

      resale_property_post = Repo.get_by(ResalePropertyPost, id: resale_property_post.id)

      conn
      |> put_status(:created)
      |> json(%{post_uuid: "#{post_type}/#{post_sub_type}/#{resale_property_post.uuid}"})
    end
  end

  def create_owner_post(_conn, %{"post_type" => _} = _params), do: {:error, "missing building_id"}

  def fetch_owner_posts(
        conn,
        params = %{
          "post_type" => _post_type
        }
      ) do
    with {posts, total_count, has_more_posts, expiry_wise_count} <- Posts.fetch_all_property_posts(params, nil, true) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_posts: has_more_posts,
        expiry_wise_count: expiry_wise_count
      })
    end
  end

  def fetch_property_posts(
        conn,
        params = %{
          "post_type" => _post_type
        }
      ) do
    with {posts, total_count, has_more_posts, expiry_wise_count} <- Posts.fetch_all_property_posts(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_posts: has_more_posts,
        expiry_wise_count: expiry_wise_count
      })
    end
  end

  def fetch_client_posts(
        conn,
        params = %{
          "post_type" => _post_type
        }
      ) do
    with {posts, total_count, has_more_posts} <- Posts.fetch_all_client_posts(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts,
        total_count: total_count,
        has_more_posts: has_more_posts
      })
    end
  end

  def verify_owner_post(
        conn,
        _params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    method_name = String.to_atom("verify_#{post_type}_property_owner_post")

    case apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, logged_in_user[:employee_role_id]]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully verified the post!"})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: inspect(error_message)})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  def edit_owner_post(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    params =
      params
      |> Map.merge(%{
        "employee_cred_id" => logged_in_user[:user_id]
      })

    case Posts.edit_owner_property_post(params, post_uuid, post_type) do
      {:ok, _post} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Post Updated Successfully"})

      {:error, errors} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: errors})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  def archive_owner_post(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    method_name = String.to_atom("archive_#{post_type}_property_owner_post")
    action_via_slash = Map.get(params, "action_via_slash", false)

    case apply(Posts, method_name, [
           logged_in_user[:user_id],
           post_uuid,
           logged_in_user[:employee_role_id],
           params["delete_reason_id"],
           action_via_slash
         ]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully archived the post!"})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: inspect(error_message)})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  def restore_owner_post(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    method_name = String.to_atom("restore_#{post_type}_property_owner_post")
    trigger_method_name = String.to_atom("trigger_#{post_type}_property_owner_matches")
    post_sub_type = "property"

    with {:ok, post} <-
           apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, logged_in_user[:employee_role_id]]),
         {_, _} <- apply(Posts, trigger_method_name, [post_uuid]) do
      MatchHelper.mark_older_owner_posts_as_unread(post.id, post_type, post_sub_type)

      conn
      |> put_status(:ok)
      |> json(%{message: "You have successfully restored the owner post!"})
    end
  end

  def refresh_owner_post(
        conn,
        %{
          "post_uuid" => post_uuid,
          "post_type" => post_type
        } = params
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    method_name = String.to_atom("refresh_#{post_type}_property_owner_post")
    action_via_slash = Map.get(params, "action_via_slash", false)

    case apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, logged_in_user[:employee_role_id], params["refreshed_reason_id"], action_via_slash]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully refreshed the owner post!"})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: inspect(error_message)})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  def refresh_reported_owner_post(conn, %{
        "post_id" => post_id,
        "post_type" => post_type,
        "refresh_note" => refresh_note
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    method_name = String.to_atom("refresh_reported_#{post_type}_property_owner_post")

    case apply(Posts, method_name, [logged_in_user[:user_id], post_id, refresh_note]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully refreshed the owner post!"})

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
  Returns FurnishTypes, FloorTypes, ConfigurationTypes
  """
  def fetch_form_data(conn, _params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    data = Posts.fetch_form_data(logged_in_user)

    conn
    |> put_status(:ok)
    |> json(data)
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
  def fetch_all_posts(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    organization_id = logged_in_user[:organization_id]
    user_id = logged_in_user[:user_id]

    with {:ok, assigned_to_me_posts, assigned_to_others_posts, has_more_posts} <-
           Posts.fetch_all_posts(organization_id, user_id, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        assigned_to_me: assigned_to_me_posts || [],
        assigned_to_others: assigned_to_others_posts || [],
        has_more_posts: has_more_posts
      })
    end
  end

  def fetch_owner_posts_polygon_distribution(conn, params) do
    with polygons <- Posts.fetch_owner_posts_polygon_distribution(params) do
      conn
      |> put_status(:ok)
      |> json(%{
        polygons: polygons
      })
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

    with {:ok, assigned_to_me_posts, assigned_to_others_posts, total_posts_count, has_more_posts} <-
           Posts.fetch_expired_posts(organization_id, user_id, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        assigned_to_me: assigned_to_me_posts || [],
        assigned_to_others: assigned_to_others_posts || [],
        has_more_posts: has_more_posts,
        total_posts_count: total_posts_count
      })
    end
  end

  @doc """
  Archive Post. Maintain a log of who did it. Only Admins or assistant who created and is assigned as well to post can do this.
  requires:
  {
    post_id: <post_uuid>,
    post_type: <rent/resale>,
    post_sub_type: <client/property>,
  }
  """
  def archive(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "post_type" => post_type,
          "post_sub_type" => post_sub_type
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("archive_#{post_type}_#{post_sub_type}_post")

    case apply(Posts, method_name, [
           logged_in_user[:user_id],
           post_uuid,
           logged_in_user[:broker_role_id],
           logged_in_user[:organization_id],
           params["delete_reason_id"]
         ]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully archived the post!"})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: inspect(error_message)})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  @doc """
  Refresh Post. Maintain a log of who did it. Only Admins or assistant who created and is assigned as well to post can do this.
  requires:
  {
    post_id: <post_uuid>,
    post_type: <rent/resale>,
    post_sub_type: <client/property>,
  }
  """
  def refresh(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type,
        "post_sub_type" => post_sub_type
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("refresh_#{post_type}_#{post_sub_type}_post")

    case apply(Posts, method_name, [
           logged_in_user[:user_id],
           post_uuid,
           logged_in_user[:broker_role_id],
           logged_in_user[:organization_id]
         ]) do
      {:ok, _} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully refreshed the post!"})

      {:error, error_message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: inspect(error_message)})

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Something went wrong"})
    end
  end

  @doc """
  Restore Post. Maintain a log of who did it. Only Admins can do this.
  requires:
  {
    post_id: <post_uuid>,
    post_type: <rent/resale>,
    post_sub_type: <client/property>,
  }
  """
  def restore(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type,
        "post_sub_type" => post_sub_type
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("restore_#{post_type}_#{post_sub_type}_post")
    trigger_method_name = String.to_atom("trigger_#{post_type}_#{post_sub_type}_matches")

    with {:ok, post} <- apply(Posts, method_name, [logged_in_user[:user_id], post_uuid]),
         {_, _} <- apply(Posts, trigger_method_name, [logged_in_user, post_uuid]) do
      MatchHelper.mark_older_posts_as_unread(logged_in_user[:user_id], post.id, post_type, post_sub_type)

      conn
      |> put_status(:ok)
      |> json(%{message: "You have successfully restored the post!"})
    end
  end

  @doc """
  Reassign Post. Maintain a log of who did it. Only Admins can do this.
  requires:
  {
    post_id: <post_uuid>,
    post_type: <rent/resale>,
    post_sub_type: <client/property>,
  }
  """
  def reassign(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type,
        "post_sub_type" => post_sub_type,
        "assigned_user_id" => assigned_user_id
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("reassign_#{post_type}_#{post_sub_type}_post")

    if logged_in_user.broker_role_id == BrokerRole.admin().id do
      with {:ok, assigned_user_id} <- Accounts.uuid_to_id(assigned_user_id),
           {:ok, _post} <- apply(Posts, method_name, [logged_in_user[:user_id], assigned_user_id, post_uuid]) do
        conn
        |> put_status(:ok)
        |> json(%{message: "You have successfully reassigned the post!"})
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Sorry, You are not authorized to call this!"})
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

    method_name = String.to_atom("fetch_#{post_type}_#{post_sub_type}_post_matches")

    with {:ok, {post_in_context, matches, total_count}} <-
           apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, page]) do
      has_more_brokers = page < Float.ceil(total_count / Posts.broker_per_page())

      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches || [],
        has_more_brokers: has_more_brokers,
        post_in_context: post_in_context
      })
    end
  end

  @doc """
  Given a post_uuid, and broker_uuid.
  Requirement: broker_uuid should be of different org than logged in user
  Return rest(except matches_per_broker limit) of the matches with that broker
  """
  def more_post_matches_with_broker(
        conn,
        params = %{
          "post_uuid" => post_uuid,
          "broker_uuid" => broker_uuid,
          "post_type" => post_type,
          "post_sub_type" => post_sub_type
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    method_name = String.to_atom("fetch_#{post_type}_#{post_sub_type}_more_post_matches_with_broker")

    with {:ok, matches} <- apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, broker_uuid, page]) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches || []
      })
    end
  end

  def own_post_matches(conn, %{
        "post_uuid" => post_uuid,
        "post_type" => post_type,
        "post_sub_type" => post_sub_type
        # "page" => page,
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)

    method_name = String.to_atom("fetch_#{post_type}_#{post_sub_type}_own_post_matches")

    with {:ok, {post_in_context, matches}} <- apply(Posts, method_name, [logged_in_user[:user_id], post_uuid, 1]) do
      conn
      |> put_status(:ok)
      |> json(%{
        matches: matches || [],
        post_in_context: post_in_context
      })
    end
  end

  def matches_with_broker(
        conn,
        params = %{
          "broker_uuid" => broker_uuid
          # "page" => page,
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    with {:ok, posts, has_more_posts} <-
           Posts.fetch_all_matches_with_broker(logged_in_user[:user_id], broker_uuid, page) do
      conn
      |> put_status(:ok)
      |> json(%{
        posts: posts || [],
        has_more_posts: has_more_posts
      })
    end
  end

  def profile_details(
        conn,
        params = %{
          "user_uuid" => broker_uuid
          # "page" => "1",
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    with {:ok, posts, has_more_posts, blocked, broker_credential, call_logs_with_broker} <-
           Posts.outsider_profile_details(logged_in_user[:user_id], broker_uuid, page) do
      render(conn, "profile_details.json",
        posts: posts,
        has_more_posts: has_more_posts,
        broker_credential: broker_credential,
        call_logs_with_broker: call_logs_with_broker,
        blocked: blocked
      )
    end
  end

  def outstanding_matches(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok, posts, has_more_posts} <-
           Posts.outstanding_matches_with_phone_number(logged_in_user[:user_id], phone_number, country_code, page) do
      render(conn, "outstanding_matches_with_broker.json",
        posts: posts,
        has_more_posts: has_more_posts
      )
    end
  end

  @doc """
    1. Mark all matches as irrelevant for the given post_uuid and logged in broker
    Requires:
      {
        post_type: "rent/resale",
        post_sub_type: "client/property"
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      }
  """
  def mark_irrelevant(
        conn,
        _params = %{
          "post_type" => post_type,
          "post_sub_type" => post_sub_type,
          "post_uuid" => post_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    method_name = String.to_atom("mark_#{post_type}_#{post_sub_type}_posts_irrelevant")

    with {_update_count, _} <- apply(Posts, method_name, [logged_in_user.user_id, [post_uuid]]) do
      conn |> put_status(:ok) |> json(%{message: "Successfully marked irrelevant"})
    else
      {:error, error_message} -> conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(error_message)})
    end
  end

  @doc """
    Requires:
    posts: [
      {
        post_type: "rent/resale",
        post_sub_type: "client/property",
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      },
      {
        post_type: "rent/resale",
        post_sub_type: "client/property",
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      }
    ]
  """
  def mark_irrelevant_bulk(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    processed_params = params |> process_bulk_params()

    processed_params
    |> Enum.each(fn {post_name, post_uuids} ->
      [post_type, post_sub_type] = post_name |> String.split("_")
      method_name = String.to_atom("mark_#{post_type}_#{post_sub_type}_posts_irrelevant")
      apply(Posts, method_name, [logged_in_user.user_id || 67, post_uuids])
    end)

    conn |> put_status(:ok) |> json(%{message: "Successfully marked irrelevant"})
  end

  @doc """
    Requires:
      {
        post_type: "rent/resale",
        post_sub_type: "client/property"
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      }
  """
  def mark_read(
        conn,
        _params = %{
          "post_type" => post_type,
          "post_sub_type" => post_sub_type,
          "post_uuid" => post_uuid
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)
    method_name = String.to_atom("mark_#{post_type}_#{post_sub_type}_match_read")

    with {_update_count, _} <- apply(Posts, method_name, [logged_in_user.user_id, [post_uuid]]) do
      conn |> put_status(:ok) |> json(%{message: "Successfully marked read"})
    else
      {:error, error_message} -> conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(error_message)})
    end
  end

  @doc """
    Requires:
    posts: [
      {
        post_type: "rent/resale",
        post_sub_type: "client/property",
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      },
      {
        post_type: "rent/resale",
        post_sub_type: "client/property",
        post_uuid: "c1a89f14-5ac4-11e9-a473-73bbc08016c1"
      }
    ]
  """
  def mark_read_bulk(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    processed_params = params |> process_bulk_params()

    processed_params
    |> Enum.each(fn {post_name, post_uuids} ->
      [post_type, post_sub_type] = post_name |> String.split("_")
      method_name = String.to_atom("mark_#{post_type}_#{post_sub_type}_match_read")
      apply(Posts, method_name, [logged_in_user.user_id, post_uuids])
    end)

    conn |> put_status(:ok) |> json(%{message: "Successfully marked read"})
  end

  defp process_bulk_params(params) do
    params = if params["posts"] |> is_list(), do: params["posts"], else: params["posts"] |> Poison.decode!()

    processed_params = %{
      "rent_client" => [],
      "rent_property" => [],
      "resale_client" => [],
      "resale_property" => []
    }

    params
    |> Enum.reduce(processed_params, fn map, acc ->
      cond do
        map["post_type"] == "rent" and map["post_sub_type"] == "client" ->
          put_in(acc, ["rent_client"], acc["rent_client"] ++ [map["post_uuid"]])

        map["post_type"] == "rent" and map["post_sub_type"] == "property" ->
          put_in(acc, ["rent_property"], acc["rent_property"] ++ [map["post_uuid"]])

        map["post_type"] == "resale" and map["post_sub_type"] == "client" ->
          put_in(acc, ["resale_client"], acc["resale_client"] ++ [map["post_uuid"]])

        true ->
          put_in(acc, ["resale_property"], acc["resale_property"] ++ [map["post_uuid"]])
      end
    end)
  end

  def report_broker(conn, %{"broker_uuid" => broker_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    {status, message} = Posts.report_all_matches_with_broker(logged_in_user[:user_id], broker_uuid)
    status = if status == :ok, do: status, else: :unprocessable_entity
    conn |> put_status(status) |> json(%{message: message})
  end

  @doc """
    Requires: text and channel(optional)

  """
  alias BnApis.Helpers.ApplicationHelper

  def notify_on_slack(conn, params = %{"text" => text}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    channel =
      case params["channel"] do
        nil -> ApplicationHelper.get_slack_building_channel()
        channel -> channel
      end

    slack_user = ApplicationHelper.get_customer_support_slack_person(logged_in_user.operating_city)

    attachments = [
      %{
        color: "#E80F0F",
        title: "Attention required !! <@#{slack_user}>"
      }
    ]

    ApplicationHelper.notify_on_slack(text, channel, attachments)
    conn |> put_status(:ok) |> json(%{message: "Successfully posted on slack"})
  end
end
