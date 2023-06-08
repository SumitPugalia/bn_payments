defmodule BnApisWeb.WhatsappController do
  use BnApisWeb, :controller
  require Logger

  alias BnApis.Whatsapp.Chat
  alias BnApis.Helpers.{Connection, Utils}
  alias BnApis.Organizations.{Organization, Broker}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.{Repo, Accounts, Posts, ProcessPostMatchWorker}
  alias BnApis.Accounts.{EmployeeRole, Credential, WhitelistedNumber, BlockedUser}
  alias BnApis.Posts.{RentalClientPost, RentalPropertyPost, ResaleClientPost, ResalePropertyPost}
  alias BnApis.Places.Polygon
  alias BnApis.Helpers.WhatsappHelper

  def create_post(
        conn,
        params = %{
          "is_bachelor" => _is_bachelor,
          # "max_rent" => max_rent, OPTIONAL
          # "notes" => notes, OPTIONAL
          "phone_number" => _phone_number,
          "building_ids" => building_ids,
          "configuration_type_ids" => configuration_type_ids,
          "furnishing_type_ids" => furnishing_type_ids,
          "chat_text" => _chat_text,
          "commit" => "true",
          "post_type" => "rent",
          "post_sub_type" => "client"
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]
    params = put_in(params, ["auto_created"], true)

    building_ids = if building_ids == "", do: [], else: building_ids |> Poison.decode!() |> Enum.uniq()
    configuration_type_ids = if configuration_type_ids == "", do: [], else: configuration_type_ids |> Poison.decode!()
    furnishing_type_ids = if furnishing_type_ids == "", do: [], else: furnishing_type_ids |> Poison.decode!()

    if logged_in_user.employee_role_id == EmployeeRole.admin().id do
      {status, result} =
        Repo.transaction(fn ->
          with(
            {:ok, credential} <- create_account_info(params, user_map),
            params =
              params
              |> Map.merge(%{
                "user_id" => credential.id,
                "assigned_user_id" => credential.id,
                "building_ids" => building_ids,
                "configuration_type_ids" => configuration_type_ids,
                "furnishing_type_ids" => furnishing_type_ids,
                "created_by_id" => logged_in_user.user_id,
                "test_post" => Accounts.is_test_post?(credential.id, credential.id)
              }),
            {:ok, _} <- RentalClientPost.check_duplicate_posts_count(params),
            {:ok, %RentalClientPost{} = rental_client_post} <- Posts.create_rental_client(params),
            {:ok, %Chat{} = _whatsapp_chat} <-
              Chat.create_whatsapp_chat_entry(params, "RentalClientPost", rental_client_post.id)
          ) do
            blocked_users = BlockedUser.fetch_blocked_users(credential.id)

            Exq.enqueue(Exq, "process_post_matches", ProcessPostMatchWorker, [
              post_type,
              post_sub_type,
              rental_client_post.id,
              blocked_users,
              [],
              rental_client_post.test_post
            ])

            %{post_uuid: "#{post_type}/#{post_sub_type}/#{rental_client_post.uuid}"}
          else
            {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(inspect(changeset.errors))
            {:error, error_message} -> Repo.rollback(error_message)
          end
        end)

      if status == :error do
        conn |> put_status(:unprocessable_entity) |> json(%{message: result})
      else
        conn |> put_status(:created) |> json(result)
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Sorry, You are not authorized to create posts!"})
    end
  end

  def create_post(
        conn,
        params = %{
          "is_bachelor_allowed" => _is_bachelor_allowed,
          "rent_expected" => _rent_expected,
          "phone_number" => _phone_number,
          "building_id" => _building_id,
          "configuration_type_id" => _configuration_type_id,
          "furnishing_type_id" => _furnishing_type_id,
          "chat_text" => _chat_text,
          "commit" => "true",
          "post_type" => "rent",
          "post_sub_type" => "property"
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]
    params = put_in(params, ["auto_created"], true)

    if logged_in_user.employee_role_id == EmployeeRole.admin().id do
      {status, result} =
        Repo.transaction(fn ->
          with(
            {:ok, credential} <- create_account_info(params, user_map),
            params =
              params
              |> Map.merge(%{
                "user_id" => credential.id,
                "assigned_user_id" => credential.id,
                "created_by_id" => logged_in_user.user_id,
                "test_post" => Accounts.is_test_post?(credential.id, credential.id)
              }),
            {:ok, _} <- RentalPropertyPost.check_duplicate_posts_count(params),
            {:ok, %RentalPropertyPost{} = rental_property_post} <- Posts.create_rental_property(params),
            {:ok, %Chat{} = _whatsapp_chat} <-
              Chat.create_whatsapp_chat_entry(params, "RentalPropertyPost", rental_property_post.id)
          ) do
            blocked_users = BlockedUser.fetch_blocked_users(credential.id)

            Exq.enqueue(Exq, "process_post_matches", ProcessPostMatchWorker, [
              post_type,
              post_sub_type,
              rental_property_post.id,
              blocked_users,
              [],
              rental_property_post.test_post
            ])

            %{post_uuid: "#{post_type}/#{post_sub_type}/#{rental_property_post.uuid}"}
          else
            {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(inspect(changeset.errors))
            {:error, error_message} -> Repo.rollback(error_message)
          end
        end)

      if status == :error do
        conn |> put_status(:unprocessable_entity) |> json(%{message: result})
      else
        conn |> put_status(:created) |> json(result)
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Sorry, You are not authorized to create posts!"})
    end
  end

  def create_post(
        conn,
        params = %{
          "building_ids" => building_ids,
          "max_budget" => _max_budget,
          "min_carpet_area" => _min_carpet_area,
          "min_parking" => _min_parking,
          "phone_number" => _phone_number,
          # "notes" => notes, OPTIONAL
          "chat_text" => _chat_text,
          "configuration_type_ids" => configuration_type_ids,
          "floor_type_ids" => floor_type_ids,
          "commit" => "true",
          "post_type" => "resale",
          "post_sub_type" => "client"
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]
    params = put_in(params, ["auto_created"], true)

    building_ids = if building_ids == "", do: [], else: building_ids |> Poison.decode!() |> Enum.uniq()
    configuration_type_ids = if configuration_type_ids == "", do: [], else: configuration_type_ids |> Poison.decode!()
    floor_type_ids = if floor_type_ids == "", do: [], else: floor_type_ids |> Poison.decode!()

    if logged_in_user.employee_role_id == EmployeeRole.admin().id do
      {status, result} =
        Repo.transaction(fn ->
          with(
            {:ok, credential} <- create_account_info(params, user_map),
            params =
              params
              |> Map.merge(%{
                "user_id" => credential.id,
                "assigned_user_id" => credential.id,
                "building_ids" => building_ids,
                "configuration_type_ids" => configuration_type_ids,
                "floor_type_ids" => floor_type_ids,
                "created_by_id" => logged_in_user.user_id,
                "test_post" => Accounts.is_test_post?(credential.id, credential.id)
              }),
            {:ok, _} <- ResaleClientPost.check_duplicate_posts_count(params),
            {:ok, %ResaleClientPost{} = resale_client_post} <- Posts.create_resale_client(params),
            {:ok, %Chat{} = _whatsapp_chat} <-
              Chat.create_whatsapp_chat_entry(params, "ResaleClientPost", resale_client_post.id)
          ) do
            blocked_users = BlockedUser.fetch_blocked_users(credential.id)

            Exq.enqueue(Exq, "process_post_matches", ProcessPostMatchWorker, [
              post_type,
              post_sub_type,
              resale_client_post.id,
              blocked_users,
              [],
              resale_client_post.test_post
            ])

            %{post_uuid: "#{post_type}/#{post_sub_type}/#{resale_client_post.uuid}"}
          else
            {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(inspect(changeset.errors))
            {:error, error_message} -> Repo.rollback(error_message)
          end
        end)

      if status == :error do
        conn |> put_status(:unprocessable_entity) |> json(%{message: result})
      else
        conn |> put_status(:created) |> json(result)
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Sorry, You are not authorized to create posts!"})
    end
  end

  def create_post(
        conn,
        params = %{
          "price" => _price,
          "carpet_area" => _carpet_area,
          "parking" => _parking,
          "phone_number" => _phone_number,
          # "notes" => notes, OPTIONAL
          "building_id" => _building_id,
          "chat_text" => _chat_text,
          "configuration_type_id" => _configuration_type_id,
          "floor_type_id" => _floor_type_id,
          "commit" => "true",
          "post_type" => "resale",
          "post_sub_type" => "property"
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    post_type = params["post_type"]
    post_sub_type = params["post_sub_type"]
    params = put_in(params, ["auto_created"], true)

    if logged_in_user.employee_role_id == EmployeeRole.admin().id do
      {status, result} =
        Repo.transaction(fn ->
          with(
            {:ok, credential} <- create_account_info(params, user_map),
            params =
              params
              |> Map.merge(%{
                "user_id" => credential.id,
                "assigned_user_id" => credential.id,
                "created_by_id" => logged_in_user.user_id,
                "test_post" => Accounts.is_test_post?(credential.id, credential.id)
              }),
            {:ok, _} <- ResalePropertyPost.check_duplicate_posts_count(params),
            {:ok, %ResalePropertyPost{} = resale_property_post} <- Posts.create_resale_property(params),
            {:ok, %Chat{} = _whatsapp_chat} <-
              Chat.create_whatsapp_chat_entry(params, "ResalePropertyPost", resale_property_post.id)
          ) do
            blocked_users = BlockedUser.fetch_blocked_users(credential.id)

            Exq.enqueue(Exq, "process_post_matches", ProcessPostMatchWorker, [
              post_type,
              post_sub_type,
              resale_property_post.id,
              blocked_users,
              [],
              resale_property_post.test_post
            ])

            %{post_uuid: "#{post_type}/#{post_sub_type}/#{resale_property_post.uuid}"}
          else
            {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(inspect(changeset.errors))
            {:error, error_message} -> Repo.rollback(error_message)
          end
        end)

      if status == :error do
        conn |> put_status(:unprocessable_entity) |> json(%{message: result})
      else
        conn |> put_status(:created) |> json(result)
      end
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "Sorry, You are not authorized to create posts!"})
    end
  end

  ## first check if credential exists
  @doc """
    1. First check if credential exists with phone
      a. If it exits check if broker id and organization id exists
      b. If either of them does not exist create and associate
    2. If credential not exists then create broker , organization and associate with new credential
  """
  def create_account_info(params, user_map) do
    params = params |> process_params()

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok, _} <- WhitelistedNumber.create_or_fetch_whitelisted_number(phone_number, country_code),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      # first check if organization is same or not
      # organization = params["organization_name"] |> Organization.fetch_organization()
      cond do
        is_nil(credential.organization_id) ->
          {:ok, %Organization{} = organization} = params |> Organization.create_organization()
          {:ok, credential} = credential |> Credential.update_organization_id(organization.id, user_map)
          {:ok, credential |> create_and_update_broker(params, user_map)}

        # is_nil(organization) ->
        #   # credential with other organization found
        #   {:error, "This phone number is already associated with other organization viz. #{Organization.get_organization(credential.organization_id).name}!!"}
        # credential.organization_id == organization.id ->
        #   # create and update broker id in the credential and return
        #   {:ok, credential |> create_and_update_broker(params)}
        true ->
          # unique check on active phone and organization
          # this clause should never be satisfied ideally
          # commenting error for now and letting post to be created with existing organization
          # {:error, "This phone number is already associated with other organization viz. #{Organization.get_organization(credential.organization_id).name}!!"}
          {:ok, credential |> create_and_update_broker(params, user_map)}
      end
    else
      {:error, %Ecto.Changeset{} = reason} ->
        Logger.error("Ecto: Whitelisting number failed", reason: reason)
        {:error, reason}

      {:error, _reason} = error ->
        error

      nil ->
        {:ok, %Organization{} = organization} = params |> Organization.create_organization()
        # create new broker here since broker is unique with orgnaization
        {:ok, %Broker{} = broker} = params |> Broker.create_broker(user_map)

        params =
          params
          |> Map.merge(%{
            "organization_id" => organization.id,
            "broker_id" => broker.id
          })

        {:ok, %Credential{} = credential} = Credential.create_or_get_credential(params, user_map)
        {:ok, credential}
    end
  end

  def process_webhook(conn, params) do
    WhatsappHelper.handle_whatsapp_webhook(params)
    conn |> put_status(:ok) |> json(%{message: "Request processed"})
  end

  defp process_params(params) do
    polygon_uuid = params["polygon_uuid"]
    country_code = Map.get(params, "country_code") || "+91"

    if is_nil(polygon_uuid) or polygon_uuid == "" do
      params
    else
      polygon = polygon_uuid |> Polygon.fetch_from_uuid()

      params
      |> Map.merge(%{
        "polygon_id" => polygon.id,
        "operating_city" => polygon.city_id,
        "country_code" => country_code
      })
    end
  end

  defp create_and_update_broker(credential, params, user_map) do
    if is_nil(credential.broker_id) do
      {:ok, broker} = params |> Broker.create_broker(user_map)
      {:ok, credential} = credential |> Credential.update_broker_id(broker.id, user_map)
      credential
    else
      credential
    end
  end
end
