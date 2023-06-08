defmodule BnApisWeb.BrokerController do
  use BnApisWeb, :controller

  alias BnApis.Organizations
  alias BnApis.Helpers.{Connection, S3Helper, AuditedRepo, Utils, Time}
  alias BnApis.Posts.{RentalMatch, ResaleMatch}
  alias BnApis.Accounts
  alias BnApis.Repo
  alias BnApis.Accounts.{EmployeeRole, Credential}
  alias BnApis.Organizations.Broker
  alias BnApis.Accounts.OwnersBrokerEmployeeMapping
  alias BnApis.Organizations.BrokerCommission
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  alias BnApis.Memberships.Membership
  alias BnApis.Packages
  alias BnApis.Orders.Order

  import Ecto.Query
  require Logger
  @allowed_assigned_employee_editable_in_sec 48 * 60 * 60
  action_fallback(BnApisWeb.FallbackController)

  plug(
    :access_check,
    [
      allowed_roles: [
        EmployeeRole.super().id,
        EmployeeRole.admin().id,
        EmployeeRole.cab_admin().id,
        EmployeeRole.broker_admin().id,
        EmployeeRole.dsa_admin().id,
        EmployeeRole.dsa_super().id
      ]
    ]
    when action in [:update_broker_type, :update_broker_info]
  )

  plug(
    :access_check,
    [
      allowed_roles: [
        EmployeeRole.super().id,
        EmployeeRole.owner_supply_admin().id,
        EmployeeRole.owner_supply_operations().id,
        EmployeeRole.broker_admin().id
      ]
    ]
    when action in [:attach_owner_employee]
  )

  @doc """
    Update profile fields
    Requires:
      {
        name: <Name of User(Broker)>,
        org_name: <Name of Brokerage Organization - Org attribute>,
        gstin: <GSTIN - Org attribute>,
        rera_id: <RERA ID - Org attribute>,
        phone_number: <Phone Number of Broker - Profile attribute> (doesn't support as it requires validation),
        rera: <RERA - RERA for Broker - Profile attribute >
        rera_name: <RERA NAME for Broker - Profile attribute>
        rera_file: <RERA File for Broker - Profile attribute>
      }
    returns {
      {string} message
    }
  """
  def update_profile(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, {_broker, _organization}} <- Organizations.update_profile(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: "You have successfully updated profile"})
    end
  end

  @doc """
    Update profile pic
    Requires:
      {
        profile_image: Multipart file, supports JPG, PNG only,
      }
    returns {
      {string} message
    }
  """
  def update_profile_pic(
        conn,
        params = %{
          "profile_image" => %Plug.Upload{
            content_type: _content_type,
            filename: _filename,
            path: _filepath
          }
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, broker} <- Organizations.update_profile_pic(logged_in_user, params) do
      profile_image = broker.profile_image

      profile_image = if !is_nil(profile_image) && !is_nil(profile_image[:url]), do: S3Helper.get_imgix_url(profile_image[:url])

      conn
      |> put_status(:ok)
      |> json(%{profile_pic_url: profile_image})
    end
  end

  @doc """
    Update pan pic
    Requires:
      {
        pan_image: Multipart file, supports JPG, PNG only,
      }
    returns {
      {string} message
    }
  """
  def update_pan_pic(
        conn,
        params = %{
          "pan_image" => %Plug.Upload{
            content_type: _content_type,
            filename: _filename,
            path: _filepath
          }
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, broker} <- Organizations.update_pan_pic(logged_in_user, params) do
      pan_image = broker.pan_image
      pan_image = if !is_nil(pan_image) && !is_nil(pan_image[:url]), do: S3Helper.get_imgix_url(pan_image[:url])

      conn
      |> put_status(:ok)
      |> json(%{pan_image: pan_image})
    end
  end

  @doc """
    Update rera doc
    Requires:
      {
        rera_file: Multipart file, supports JPG, PNG only,
      }
    returns {
      {string} message
    }
  """
  def update_rera_file(
        conn,
        params = %{
          "rera_file" => %Plug.Upload{
            content_type: _content_type,
            filename: _filename,
            path: _filepath
          }
        }
      ) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, broker} <- Organizations.update_rera_file(logged_in_user, params) do
      rera_file = broker.rera_file
      rera_file = if !is_nil(rera_file) && !is_nil(rera_file[:url]), do: S3Helper.get_imgix_url(rera_file[:url])

      conn
      |> put_status(:ok)
      |> json(%{rera_file: rera_file})
    end
  end

  @doc """
    1. Mark all matches as contacted for the given broker and logged in broker
    Requires:
      {
        broker_uuid: "a9227510-5a91-11e9-a473-bbf7d1696c22"
      }
  """
  def mark_contacted(conn, _params = %{"broker_uuid" => broker_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_id = logged_in_user.user_id

    with(
      {:ok, broker_id} <- Accounts.uuid_to_id(broker_uuid),
      {_, _} <- RentalMatch.mark_matches_against_each_other_as_contacted(user_id, broker_id, user_id),
      {_, _} <- ResaleMatch.mark_matches_against_each_other_as_contacted(user_id, broker_id, user_id),
      {:ok, feedback_session} <-
        BnApis.Feedbacks.create_feedback_session(%{
          initiated_by_id: broker_id,
          start_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          source: %{}
        })
    ) do
      conn |> put_status(:ok) |> json(%{feedback_session_id: feedback_session.uuid})
    else
      {:error, error_message} -> conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(error_message)})
    end
  end

  def mark_contacted_owner(conn, _params = %{"post_type" => post_type, "post_uuid" => post_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_id = logged_in_user.user_id

    with(
      case post_type do
        "rent" ->
          RentalMatch.mark_matches_against_owner_as_contacted(user_id, post_uuid, user_id)

        "resale" ->
          ResaleMatch.mark_matches_against_owner_as_contacted(user_id, post_uuid, user_id)
      end,
      {:ok, feedback_session} <-
        BnApis.Feedbacks.create_feedback_session(%{
          initiated_by_id: user_id,
          start_time: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          source: %{}
        })
    ) do
      conn |> put_status(:ok) |> json(%{feedback_session_id: feedback_session.uuid})
    else
      {:error, error_message} -> conn |> put_status(:unprocessable_entity) |> json(%{message: inspect(error_message)})
    end
  end

  def index(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    employee_role_id = logged_in_user.employee_role_id
    user_id = logged_in_user.user_id

    {brokers, has_more_brokers, total_count} = Broker.index(params, employee_role_id, user_id)

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.BrokerView, "index.json", %{
      brokers: brokers,
      has_more_brokers: has_more_brokers,
      total_count: total_count
    })
  end

  def all_brokers(conn, params) do
    {brokers, has_more_brokers} = Broker.all_active_brokers(params)

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.BrokerView, "list.json", %{brokers: brokers, has_more_brokers: has_more_brokers})
  end

  def show(conn, %{"id" => id}) do
    broker = Broker.fetch_broker_from_id(id)

    if broker |> is_nil() do
      conn |> put_status(:not_found) |> json(%{message: "Broker does not exist!!"})
    else
      conn
      |> put_status(:ok)
      |> render(BnApisWeb.BrokerView, "show.json", %{broker: broker})
    end
  end

  def update_broker_type(conn, %{"broker_type_id" => broker_type_id} = params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      broker = credential.broker_id |> Accounts.get_broker!()
      broker |> Broker.broker_type_changeset(broker_type_id) |> AuditedRepo.update(user_map)
      conn |> put_status(:ok) |> json(%{message: "Successfully updated type of the broker"})
    else
      {:error, _} ->
        {:error, "Invalid phone number or country code"}

      nil ->
        conn |> put_status(:not_found) |> json(%{message: "Phone number does not exists or is inactive!!"})
    end
  end

  def update_broker_info(conn, params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      broker = credential.broker_id |> Accounts.get_broker!()
      logged_in_user = Connection.get_employee_logged_in_user(conn)
      user_map = Utils.get_user_map(logged_in_user)

      cond do
        logged_in_user.employee_role_id == EmployeeRole.cab_admin().id ->
          broker
          |> Broker.info_changeset(%{"is_cab_booking_enabled" => params["is_cab_booking_enabled"]})
          |> AuditedRepo.update(user_map)

          conn |> put_status(:ok) |> json(%{message: "Successfully updated info of the broker"})

        broker.role_type_id == Broker.dsa()["id"] ->
          if(Enum.member?([EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id], logged_in_user.employee_role_id)) do
            BrokerCommission.update_broker_commission_detail(credential.broker_id, params, user_map)
            broker |> Broker.info_changeset(params) |> AuditedRepo.update(user_map)
            conn |> put_status(:ok) |> json(%{message: "Successfully updated info of the broker"})
          else
            conn |> put_status(:ok) |> json(%{message: "Employee isn't authorize to take this action"})
          end

        true ->
          broker |> Broker.info_changeset(params) |> AuditedRepo.update(user_map)
          conn |> put_status(:ok) |> json(%{message: "Successfully updated info of the broker"})
      end
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{message: "Phone number does not exists or is inactive!!"})
    end
  end

  def update_broker_kyc_details(conn, params) do
    logged_in_user = Connection.get_logged_in_user(conn)
    broker_id = logged_in_user.broker_id
    cred_id = logged_in_user.user_id
    user_map = Utils.get_user_map(logged_in_user)

    case Broker.update_broker_kyc_details(params, broker_id, cred_id, user_map) do
      {:ok, conflicts} when is_list(conflicts) and length(conflicts) > 0 ->
        conn
        |> put_status(:ok)
        |> json(%{conflicts: conflicts})

      {:ok, _broker} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "KYC updated successfully."})

      {:error, error} ->
        {:error, error}
    end
  end

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

  @doc """
    #1. generate pdf from html of the logged in user
    #2. fetch broker kit document from s3
    #3. append above pdf in step 1 at the end of doc fetched in step 2
    #4. upload to s3 and save that s3 url
  """
  def broker_kit(conn, %{"phone_number" => phone_number}) do
    credential =
      Credential
      |> where(phone_number: ^phone_number)
      |> Repo.all()
      |> List.last()

    Exq.enqueue(
      Exq,
      "broker_kit_generator",
      BnApis.BrokerKitWorker,
      [credential.broker_id]
    )

    conn |> put_status(:ok) |> json(%{message: "Success", data: %{url: ""}})
  end

  def attach_owner_employee(conn, %{
        "employees_credentials_id" => employees_credentials_id,
        "broker_id" => broker_id,
        "payment_gateway" => payment_gateway,
        "subscription_id" => subscription_id
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    is_editable =
      cond do
        payment_gateway == "paytm" ->
          membership = Membership.get_membership_by(%{paytm_subscription_id: subscription_id})
          is_editable?(membership.created_at)

        payment_gateway == "razorpay" ->
          order_payment =
            %{razorpay_order_id: subscription_id}
            |> Order.get_order_by()
            |> Order.get_captured_payment()

          is_editable?(order_payment.created_at)

        payment_gateway == "billdesk" ->
          user_package = Packages.get_user_package_by(%{id: subscription_id}, [:user_order])

          is_editable?(user_package.user_order.created_at)
      end

    if is_editable do
      {_, obem} =
        OwnersBrokerEmployeeMapping.create_owners_broker_employee_mapping(
          employees_credentials_id,
          broker_id,
          logged_in_user.user_id
        )

      conn |> put_status(:ok) |> json(%{message: "Success", id: obem.id})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{message: "you are not allowed to assign manager"})
    end
  end

  def attach_owner_employee(conn, %{
        "employees_credentials_id" => employees_credentials_id,
        "broker_id" => broker_id
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    {_, obem} =
      OwnersBrokerEmployeeMapping.create_owners_broker_employee_mapping(
        employees_credentials_id,
        broker_id,
        logged_in_user.user_id
      )

    conn |> put_status(:ok) |> json(%{message: "Success", id: obem.id})
  end

  def update_broker_status(conn, params = %{"id" => broker_id, "status" => status}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, message} <- Broker.update_broker_status(broker_id, status, params["rejected_reason"], user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: message, id: broker_id})
    end
  end

  def get_profile_details(conn, _params) do
    credential_uuid = conn.assigns[:user]["uuid"]

    with {:ok, profile_details} <- Broker.get_profile_details(credential_uuid) do
      conn
      |> put_status(:ok)
      |> json(%{profile: profile_details["profile"]})
    end
  end

  defp is_editable?(created_timestamp), do: Time.now_to_epoch() - created_timestamp * 1000 < @allowed_assigned_employee_editable_in_sec * 1_000

  def fetch_brokers_with_no_og_employee(conn, params) do
    with {brokers, has_more_brokers, total_count} <- Broker.fetch_brokers_with_no_og_employee(params) do
      conn
      |> put_status(:ok)
      |> render(BnApisWeb.BrokerView, "index.json", %{
        brokers: brokers,
        has_more_brokers: has_more_brokers,
        total_count: total_count
      })
    end
  end
end
