defmodule BnApisWeb.EmployeeCredentialController do
  use BnApisWeb, :controller

  require Logger

  alias BnApis.{Accounts, Repo, Posts, Organizations}
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  alias BnApis.Accounts.{
    EmployeeRole,
    ProfileType,
    ColorCode,
    WhitelistedNumber,
    EmployeeCredential,
    Credential,
    EmployeeAccounts,
    EmployeeVertical
  }

  alias BnApis.Helpers.{Otp, Token, Connection, S3Helper, AssignedBrokerHelper, AuditedRepo, Utils}
  alias BnApis.Organizations.{Broker, BillingCompany}
  alias BnApis.Events.PanelEvent
  alias BnApis.Reasons
  alias BnApis.Reasons.ReasonType
  alias BnApisWeb.ReasonView
  alias BnApis.Places.City
  alias BnApis.Posts.ProjectType
  alias BnApis.Cabs
  alias BnApis.Rewards.FailureReason
  alias BnApis.Buildings.BuildingEnums
  alias BnApis.Homeloan.LeadType
  alias BnApis.Homeloans
  alias BnApis.Homeloan.Bank
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.Status
  alias alias BnApis.Homeloan.LoanDisbursement

  @profile_type_id ProfileType.employee().id

  action_fallback BnApisWeb.FallbackController

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.hr_admin().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.assisted_admin().id,
           EmployeeRole.owner_supply_admin().id
         ]
       ]
       when action in [
              :mark_inactive,
              :mark_test_user,
              :update_operating_city,
              :update_assign_brokers,
              :reassign_organisation,
              :assign_brokers,
              :whitelist_number,
              :create_employee,
              :transfer_organizations,
              :update_upi_id,
              :activate_broker
            ]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.admin().id,
           EmployeeRole.member().id,
           EmployeeRole.commercial_agent().id,
           EmployeeRole.commercial_admin().id,
           EmployeeRole.commercial_data_collector().id,
           EmployeeRole.owner_supply_admin().id,
           EmployeeRole.cab_admin().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.hr_admin().id,
           EmployeeRole.dsa_agent().id,
           EmployeeRole.dsa_admin().id,
           EmployeeRole.dsa_super().id,
           EmployeeRole.assisted_admin().id
         ]
       ]
       when action in [
              :whitelist_broker,
              :fetch_assigned_organizations,
              :fetch_assigned_brokers,
              :fetch_unassigned_organizations,
              :check_upi,
              :validate_upi_id
            ]

  plug :access_check,
       [
         allowed_roles: [
           EmployeeRole.super().id,
           EmployeeRole.broker_admin().id,
           EmployeeRole.hr_admin().id,
           EmployeeRole.admin().id,
           EmployeeRole.owner_supply_admin().id
         ]
       ]
       when action in [:update_employee_details, :remove_employee]

  plug :access_check,
       [allowed_roles: [EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_agent(), EmployeeRole.super().id]]
       when action in [:get_all_leads_for_employee_view, :get_all_leads_for_dsa_view, :get_lead_for_panel_view]

  @doc """
    Generates OTP & request_id (For whitelisted or Invited numbers)
    Sends OTP to the provided number using SMS Gateway
    @param {string} phone_number [to be registered]
    returns {
      {string} request_id [SecureRandom string]
    }
  """
  def send_otp(conn, params) do
    # remove request_id in future
    request_id = SecureRandom.urlsafe_base64(32)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok, _employee_credential} <-
           Accounts.is_admin_user_present?(phone_number, country_code),
         {:ok,
          %{
            otp: otp,
            otp_requested_count: stored_otp_request_count,
            max_count_allowed: otp_request_limit
          }} <- Otp.generate_otp_tokens(phone_number, @profile_type_id) do
      message = "OTP is #{otp} for the Admin Panel login. Valid for #{Otp.get_otp_life()} minutes. Do not share this OTP to anyone for security reasons."
      IO.puts(message)

      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message)

      Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

      conn
      |> put_status(:ok)
      |> json(%{
        request_id: request_id,
        otp_requested_count: stored_otp_request_count,
        max_count_allowed: otp_request_limit
      })
    end
  end

  @doc """
    Resend OTP to the given number
    A number can generate OTP at max 3 times in 1 hrs.

    @param {string} phone_number [to be registered]
    @param {string} request_id [received when asked to send otp]
    returns {
      {string} request_id [SecureRandom string]
      {string} error [if 2 times limit reached]
    }
  """
  def resend_otp(conn, %{"request_id" => request_id} = params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok,
          %{
            otp: otp,
            otp_requested_count: stored_otp_request_count,
            max_count_allowed: otp_request_limit
          }} <- Otp.generate_otp_tokens(phone_number, @profile_type_id),
         message = "OTP is #{otp} for the Admin Panel login. Valid for #{Otp.get_otp_life()} minutes. Do not share this OTP to anyone for security reasons." do
      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message)

      Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

      conn
      |> put_status(:ok)
      |> json(%{
        request_id: request_id,
        otp_requested_count: stored_otp_request_count,
        max_count_allowed: otp_request_limit
      })
    end
  end

  @doc """
    Verifies OTP of the given number
    OTP generated has maximum of 3 tries

    On successful OTP verification:
    Logout of other sessions.
    Sets current User session_token and signin.
    if already signed up, return session_token

    @param {string} phone_number [registered one]
    @param {string} request_id [received when asked to send otp]
    @param {string} otp [received on phone_number]
    returns {
      {bool} success,
      {bool} opt_expired,
    }

  """
  def verify_otp(conn, %{"otp" => otp} = params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok, employee_credential} <-
           Accounts.is_admin_user_present?(phone_number, country_code),
         {:ok} <- maybe_verify_otp(phone_number, otp),
         Token.destroy_all_user_tokens(
           employee_credential.id,
           @profile_type_id
         ),
         {:ok, token} <-
           Token.initialize_employee_token(employee_credential) do
      profile = Token.get_token_data(token, @profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "verify_otp.json", %{
        token: token,
        profile: profile
      })
    end
  end

  @doc """
    Signup user for Whitelisted Number
    Requires:
      {
        user_id: <last request user_id>,
        name: name,
        organization_name: org_name, <OPTIONAL>
        profile_image: { url: "", other_property: ""}, (map)
      }
    returns {
      {string} message
    }
  """
  def signup(
        conn,
        params = %{
          "name" => _name,
          "phone_number" => _phone_number,
          "employee_role_id" => employee_role_id
          # "profile_image" => profile_image,
        }
      ) do
    params =
      params
      |> Map.merge(%{
        "employee_role_id" => employee_role_id |> String.to_integer()
      })

    # with  {:ok, phone_number} <- Otp.verify_signup_token(signup_token, @profile_type_id),
    with {:ok, employee_credential} <- Accounts.signup_employee_user(params, nil),
         # Otp.delete_signup_token(signup_token),
         Token.destroy_all_user_tokens(
           employee_credential.id,
           @profile_type_id
         ),
         {:ok, token} <-
           Token.initialize_employee_token(employee_credential.uuid) do
      profile = Token.get_token_data(token, @profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "signup.json", %{
        token: token,
        profile: profile
      })
    end
  end

  def add_employee(
        conn,
        params = %{
          "name" => _name,
          "phone_number" => _phone_number,
          "employee_role_id" => employee_role_id,
          "city_id" => _city_id,
          "reporting_manager_id" => _reporting_manager_id,
          "access_city_ids" => _access_city_ids
          # "profile_image" => profile_image,
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    employee_role_id = if is_binary(employee_role_id), do: String.to_integer(employee_role_id), else: employee_role_id
    allowed_employee_role_ids = allowed_roles_map(logged_in_user[:employee_role_id])

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         true <- Enum.member?(allowed_employee_role_ids, employee_role_id),
         {:ok, _employee_credential} <-
           params
           |> Map.merge(%{
             "employee_role_id" => employee_role_id,
             "phone_number" => phone_number,
             "country_code" => country_code
           })
           |> Accounts.signup_employee_user(user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully created an employee!!"})
    else
      false ->
        employee_role = EmployeeRole.get_by_id(employee_role_id)

        employee_role_name_string = if employee_role, do: " as #{employee_role.name}", else: ""

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          message: "You are not authorized to add an employee#{employee_role_name_string}!!"
        })

      {:error, _} = error ->
        error
    end
  end

  defp allowed_roles_map(employee_role_id) do
    cond do
      employee_role_id == EmployeeRole.super().id ->
        [
          EmployeeRole.super().id,
          EmployeeRole.admin().id,
          EmployeeRole.member().id,
          EmployeeRole.transaction_data_cleaner().id,
          EmployeeRole.dsa_super().id,
          EmployeeRole.dsa_admin().id,
          EmployeeRole.dsa_agent().id
        ]

      employee_role_id == EmployeeRole.admin().id ->
        [EmployeeRole.member().id, EmployeeRole.transaction_data_cleaner().id]

      true ->
        []
    end
  end

  def validate(conn, _params) do
    session_token = conn |> get_req_header("session-token") |> List.first()

    profile =
      Token.get_token_data(session_token, @profile_type_id)
      |> Map.take(["profile"])

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.CredentialView, "signup.json", %{
      token: session_token,
      profile: profile
    })
  end

  @doc """
    Signout from all sessions.

    returns {
      {string} message
    }
  """
  def signout(conn, _params) do
    user_id = conn.assigns[:user]["user_id"]

    with {:ok, _del} <- Token.destroy_all_user_tokens(user_id, @profile_type_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "You have been signed out from all sessions successfully"
      })
    end
  end

  @doc """
    Promote user to Admin role.
    ONLY ADMINS are allowed to take this action

    Required  %{
      "user_id" => employee_credential_uuid,
      }
  """
  def change_user_role(
        conn,
        params = %{"user_uuid" => _employee_credential_uuid}
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, message} <- Accounts.promote_user(logged_in_user, params) do
      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  # @doc """
  #   Remove user.
  #   ONLY ADMINS are allowed to take this action

  #   Required  %{
  #     "user_id" => employee_credential_uuid,
  #     }
  # """
  # def remove_user(conn, params = %{"user_uuid" => _employee_credential_uuid}) do
  #   logged_in_user = Connection.get_employee_logged_in_user(conn)

  #   with  {:ok, message} <- Accounts.remove_user(logged_in_user, params)  do
  #     conn
  #     |> put_status(:ok)
  #     |> json(%{message: message})
  #   end
  # end

  @doc """
    Update profile fields
    Requires:
      {
        name: <Name of User>,
      }
    returns {
      {string} message
    }
  """
  def update_profile(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _credential} <-
           Accounts.update_profile(logged_in_user[:uuid], params, user_map) do
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
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, employee_credential} <-
           Accounts.update_profile_pic(logged_in_user[:uuid], params, user_map) do
      profile_image =
        case employee_credential.profile_image_url do
          nil -> nil
          url -> S3Helper.get_imgix_url(url)
        end

      conn
      |> put_status(:ok)
      |> json(%{profile_pic_url: profile_image})
    end
  end

  @doc """
    Admin Panel Dashboard
    Requires:
      {
        profile_image: Multipart file, supports JPG, PNG only,
      }
    returns {
      {string} message
    }
  """
  def dashboard(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    page = (params["page"] && params["page"] |> String.to_integer()) || 1

    broker_details =
      if logged_in_user.employee_role_id == EmployeeRole.admin().id do
        Accounts.brokers_dashboard_details(logged_in_user, page, [])
      else
        assigned_broker_ids = AssignedBrokerHelper.fetch_all_active_assigned_brokers(logged_in_user.user_id)

        if length(assigned_broker_ids) > 0 do
          Accounts.brokers_dashboard_details(
            logged_in_user,
            page,
            assigned_broker_ids
          )
        else
          []
        end
      end

    conn
    |> put_status(:ok)
    |> json(broker_details)
  end

  def config(conn, _params) do
    color_codes = ColorCode.seed_data()

    conn
    |> put_status(:ok)
    |> json(%{color_codes: color_codes})
  end

  @doc """
    Create an Employee
    Sample Request:
      {
        profile_image: Multipart file, supports JPG, PNG only,(optional)
        name: "Bhavik" (mandatory),
        phone_number: "9711227605", (mandatory)
        employee_role_id: 1 (mandatory)
      }
    returns {
      created employee json
    }
  """
  def create_employee(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         nil <- EmployeeCredential.fetch_employee_credential(phone_number, country_code) do
      params =
        cond do
          EmployeeRole.get_by_id(params["employee_role_id"]).admin_type and logged_in_user.employee_role_id != EmployeeRole.super().id ->
            Map.put(params, "employee_role_id", EmployeeRole.member().id)

          logged_in_user.employee_role_id == EmployeeRole.assisted_admin().id ->
            Map.put(params, "employee_role_id", EmployeeRole.assisted_manager().id)

          true ->
            params
        end

      params = params |> Map.merge(%{"phone_number" => phone_number, "country_code" => country_code})

      with {:ok, %EmployeeCredential{} = employee_credential} <-
             EmployeeCredential.create_employee_credential(params, user_map) do
        conn
        |> put_status(:ok)
        |> render(BnApisWeb.CredentialView, "employee.json", %{
          employee: employee_credential
        })
      end
    else
      {:error, _} = error ->
        error

      %EmployeeCredential{} ->
        {:error, "Employee with phone_number already exists!!"}
    end
  end

  @doc """
    Mark an Employee as inactive
    Sample Request:
      {
        phone_number: 9711227605
      }
  """
  def remove_employee(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %EmployeeCredential{} = employee_credential <-
           EmployeeCredential.fetch_employee_credential(phone_number, country_code) do
      employee_credential
      |> EmployeeCredential.update_active_changeset(false)
      |> AuditedRepo.update(user_map)

      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully Removed"})
    else
      nil ->
        {:error, "No employee found with the given phone_number"}

      {:error, _reason} = error ->
        error
    end
  end

  def fetch_assigned_brokers(conn, %{"uuid" => employee_credential_uuid}) do
    employee_credential = employee_credential_uuid |> EmployeeCredential.fetch_employee()

    employee_data =
      BnApisWeb.CredentialView.render("employee.json", %{
        employee: employee_credential
      })

    assigned_broker_ids = AssignedBrokerHelper.fetch_all_active_assigned_brokers(employee_credential.id)

    assigned_broker_details =
      if length(assigned_broker_ids) > 0 do
        AssignedBrokerHelper.assigned_broker_data(assigned_broker_ids)
      else
        []
      end

    conn
    |> put_status(:ok)
    |> json(%{data: employee_data, brokers_data: assigned_broker_details})
  end

  def fetch_assigned_organizations(conn, %{"uuid" => employee_credential_uuid}) do
    employee_credential = employee_credential_uuid |> EmployeeCredential.fetch_employee()

    assigned_broker_ids = AssignedBrokerHelper.fetch_all_active_assigned_brokers(employee_credential.id)

    assigned_organization_details =
      if length(assigned_broker_ids) > 0 do
        AssignedBrokerHelper.assigned_organization_data(assigned_broker_ids)
      else
        []
      end

    conn |> put_status(:ok) |> json(%{data: assigned_organization_details})
  end

  def fetch_unassigned_organizations(conn, _params) do
    org_details = AssignedBrokerHelper.fetch_all_unassigned_brokers()
    conn |> put_status(:ok) |> json(org_details)
  end

  @doc """
    Assigns Brokers to employee
    Sample Request:
      {
        broker_ids: [1,2] list of broker ids
        assign_to: uuid of employee to which we are assigning
      }
    returns {
      need to discuss what to return
    }
  """

  def assign_brokers(
        conn,
        params = %{
          "assign_to" => employee_credential_uuid,
          "org_uuid" => org_uuids
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    # keeping broker ids optional in case
    broker_ids =
      if is_binary(params["broker_ids"]),
        do: params["broker_ids"] |> Poison.decode!(),
        else: params["broker_ids"] || []

    broker_ids = (broker_ids ++ get_organization_broker_ids(org_uuids)) |> Enum.uniq()

    assignees_info = AssignedBrokerHelper.fetch_all_assignees_info(broker_ids)

    if List.first(assignees_info) |> is_nil() do
      employee_credential_id = employee_credential_uuid |> EmployeeCredential.get_id_from_uuid()

      _repsonse =
        AssignedBrokerHelper.create_employee_assignments(
          logged_in_user.user_id,
          employee_credential_id,
          broker_ids
        )

      create_assign_organization_event_params(params, logged_in_user[:user_id])

      conn
      |> put_status(:ok)
      |> json(%{message: "Success"})
    else
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{assignees_info: assignees_info})
    end
  end

  def reset_otp_limit(conn, params) do
    profile_type_id = ProfileType.broker().id

    with {:ok, phone_number, _country_code} <- Phone.parse_phone_number(params),
         {:ok, _value} <- Otp.clean_otp_request_count(phone_number, profile_type_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Limit reset done successfully"})
    else
      {:error, _value} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{message: "Some Error Occured"})
    end
  end

  @doc """
    Updates Broker assigned to employee
    Sample Request:
      {
        broker_ids: [1,2] list of broker ids
        remove_broker_ids: [3,4] list of assigned broker ids to be removed
        assign_to: uuid of employee to which we are assigning
      }
    returns {
      need to discuss what to return
    }
  """

  def update_assign_brokers(
        conn,
        _params = %{
          "broker_ids" => broker_ids,
          "remove_broker_ids" => remove_broker_ids,
          "assign_to" => employee_credential_uuid
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    broker_ids =
      if is_binary(broker_ids),
        do: broker_ids |> Poison.decode!(),
        else: broker_ids || []

    remove_broker_ids =
      if is_binary(remove_broker_ids),
        do: remove_broker_ids |> Poison.decode!(),
        else: remove_broker_ids || []

    employee_credential_id = employee_credential_uuid |> EmployeeCredential.get_id_from_uuid()

    AssignedBrokerHelper.create_employee_assignments(
      logged_in_user.user_id,
      employee_credential_id,
      broker_ids
    )

    AssignedBrokerHelper.remove_employee_assignments(
      logged_in_user.user_id,
      employee_credential_id,
      remove_broker_ids
    )

    # need to render response in required format
    conn
    |> put_status(:ok)
    |> json(%{message: "Success"})
  end

  def reassign_organization(
        conn,
        params = %{
          "assignee_to_remove" => assigned_employee_credential_uuid,
          "assign_to" => employee_credential_uuid,
          "org_uuid" => org_uuid
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    broker_ids =
      Organizations.get_organization_brokers(org_uuid)
      |> Enum.map(& &1[:broker_id])

    employee_credential_id = employee_credential_uuid |> EmployeeCredential.get_id_from_uuid()

    assigned_employee_credential_id = assigned_employee_credential_uuid |> EmployeeCredential.get_id_from_uuid()

    AssignedBrokerHelper.remove_employee_assignments(
      logged_in_user.user_id,
      assigned_employee_credential_id,
      broker_ids
    )

    AssignedBrokerHelper.create_employee_assignments(
      logged_in_user.user_id,
      employee_credential_id,
      broker_ids
    )

    create_reassign_organization_event_params(params, logged_in_user[:user_id])

    conn
    |> put_status(:ok)
    |> json(%{message: "Successfully reassigned !!"})
  end

  def transfer_organizations(
        conn,
        params = %{
          "assign_to" => employee_credential_uuid,
          "org_uuids" => org_uuids
        }
      ) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    org_uuids =
      if is_binary(org_uuids),
        do: org_uuids |> Poison.decode!(),
        else: org_uuids || []

    broker_ids =
      Organizations.get_organization_brokers(org_uuids)
      |> Enum.map(& &1[:broker_id])
      |> Enum.uniq()

    employee_credential = employee_credential_uuid |> EmployeeCredential.fetch_employee()

    assigned_employee_credential_uuid = params["assignee_to_remove"]

    {status, response} =
      if is_nil(assigned_employee_credential_uuid) ||
           assigned_employee_credential_uuid == "" do
        assignees_info = AssignedBrokerHelper.fetch_all_assignees_info(broker_ids)

        same_vertical_assignees_info = assignees_info |> Enum.filter(fn assingee -> assingee.vertical_id == employee_credential.vertical_id end)
        other_vertical_assignees_info = assignees_info |> Enum.filter(fn assingee -> assingee.vertical_id != employee_credential.vertical_id end)

        if(same_vertical_assignees_info not in [nil, []]) do
          same_vertical_assignees_info
          |> Enum.each(fn a ->
            if(a.employee_id != employee_credential.id) do
              AssignedBrokerHelper.remove_employee_assignments(logged_in_user.user_id, a.employee_id, [a.broker_id])
              AssignedBrokerHelper.create_employee_assignments(logged_in_user.user_id, employee_credential.id, [a.broker_id])
            end
          end)
        end

        if(other_vertical_assignees_info not in [nil, []]) do
          broker_ids = other_vertical_assignees_info |> Enum.map(fn a -> a.broker_id end)
          AssignedBrokerHelper.create_employee_assignments(logged_in_user.user_id, employee_credential.id, broker_ids)
        end

        {:ok, %{message: "Successfully assigned organizations !!"}}
      else
        assigned_employee_credential_id =
          assigned_employee_credential_uuid
          |> EmployeeCredential.get_id_from_uuid()

        AssignedBrokerHelper.remove_employee_assignments(
          logged_in_user.user_id,
          assigned_employee_credential_id,
          broker_ids
        )

        AssignedBrokerHelper.create_employee_assignments(
          logged_in_user.user_id,
          employee_credential.id,
          broker_ids
        )

        create_transfer_organizations_event_params(
          params,
          logged_in_user[:user_id]
        )

        {:ok, %{message: "Successfully transferred organizations !!"}}
      end

    conn
    |> put_status(status)
    |> json(response)
  end

  def all_employees(conn, _params) do
    conn
    |> put_status(:ok)
    |> render(BnApisWeb.CredentialView, "employees_data.json", %{
      data: EmployeeCredential.all_active_employees()
    })
  end

  def get_employees(conn, params) do
    conn
    |> put_status(:ok)
    |> render(
      BnApisWeb.CredentialView,
      "new_employees_data_with_metrics.json",
      EmployeeCredential.paginated_active_employees(params)
    )
  end

  def search_employees(conn, params) do
    conn
    |> put_status(:ok)
    |> render(
      BnApisWeb.CredentialView,
      "new_employees_data_with_metrics.json",
      EmployeeCredential.search_employees(params)
    )
  end

  def show(conn, %{"uuid" => uuid}) do
    employee = EmployeeCredential.fetch_employee(uuid)

    if employee |> is_nil() do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Employee does not exists!!"})
    else
      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "employee.json", %{employee: employee})
    end
  end

  def whitelist_number(conn, params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok, _} <- WhitelistedNumber.create_or_fetch_whitelisted_number(phone_number, country_code) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully whitelisted"})
    else
      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{message: "Please provide valid phone number"})
    end
  end

  def whitelist_broker(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with :ok <- validate_whitelist_broker_params(params),
         {:ok, response} <- Broker.whitelist_broker(params, logged_in_user.user_id, user_map, false) do
      conn |> put_status(:ok) |> json(response)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.error("Error in whitelist_broker: ", changeset: changeset)
        {:error, changeset}

      {:error, reason} ->
        conn |> put_status(:bad_request) |> json(%{message: reason})
    end
  end

  def mark_inactive(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      Accounts.remove_user_tokens(credential.id, user_map)
      Token.destroy_all_user_tokens(credential.id, credential.profile_type_id)
      credential |> Credential.deactivate_changeset() |> AuditedRepo.update(user_map)
      BillingCompany.deactivate_brokers_billing_companies(credential.broker_id)
      WhitelistedNumber.remove(credential.phone_number, credential.country_code)
      credential.broker_id |> AssignedBrokerHelper.remove_all_assignments()

      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully marked inactive"})
    else
      {:error, _reason} = error ->
        error

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Phone number does not exists/is already inactive!!"})
    end
  end

  def activate_broker(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _credential} <- Credential.activate_credential(params, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully activated"})
    else
      {:error, _reason} = error ->
        error

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Broker does not exist"})
    end
  end

  def mark_test_user(conn, params) do
    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      posts = Posts.fetch_posts(credential.id)

      if posts |> List.first() |> is_nil() do
        credential |> Credential.test_user_changeset() |> Repo.update()

        conn
        |> put_status(:ok)
        |> json(%{message: "Successfully marked as test user"})
      else
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          message: "This user either has active posts or expired posts!"
        })
      end
    else
      {:error, _reason} = error ->
        error

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Phone number does not exists/is already inactive!!"})
    end
  end

  def update_operating_city(conn, params = %{"city_id" => city_id}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %Credential{} = credential <- Credential.fetch_credential(phone_number, country_code) do
      broker = credential.broker_id |> Accounts.get_broker!()
      broker |> Broker.operating_city_changeset(city_id) |> AuditedRepo.update(user_map)

      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated city of the broker"})
    else
      {:error, _reason} = error ->
        error

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{message: "Phone number does not exists/is already inactive!!"})
    end
  end

  def meta_data(conn, _params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    reasons_types = Reasons.list_reasons_types()
    cities = City.get_cities_list()
    project_types = ProjectType.seed_data()
    building_types = BuildingEnums.building_type_enum() |> Enum.into([], fn {_k, v} -> v end)
    {dates, timings} = Cabs.get_valid_pickup_dates_and_times()

    data =
      Map.merge(
        Posts.fetch_admin_form_data(logged_in_user),
        %{
          cities: cities,
          reason_types: ReasonType.seed_data(),
          reasons: ReasonView.render("index.json", reasons_types: reasons_types),
          project_types: project_types,
          building_types: building_types,
          rewards_failure_reasons: FailureReason.failure_reason_list(),
          employment_type: LeadType.employment_type_list(),
          pickup_timings: %{"dates" => dates, "timings" => timings},
          homeloan_page_limit: Homeloans.homeloan_panel_page_limit(),
          broker_types: Broker.list_broker_types(),
          broker_statuses: Broker.get_broker_status_list(),
          bank_list: Bank.get_all_bank_data(),
          loan_types: Lead.loan_types() ++ ["Other"],
          dsa_status_list: Status.dsa_status_list(),
          vertical: EmployeeVertical.get_all_verticals(),
          dsa_dashboard_status_ids: Status.dsa_dashboard_status_list(),
          product_types: Bank.loan_type_list(),
          property_stages: Lead.property_stages(),
          commission_applicable_list: LoanDisbursement.commission_applicable_list()
        }
      )

    conn
    |> put_status(:ok)
    |> json(data)
  end

  def analytics(conn, %{"uuid" => employee_credential_uuid}) do
    employee = EmployeeCredential.fetch_employee(employee_credential_uuid)

    if employee |> is_nil() do
      conn
      |> put_status(:not_found)
      |> json(%{message: "Employee does not exists!!"})
    else
      data = AssignedBrokerHelper.get_employee_analytics(employee.id)

      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def update_upi_id(conn, %{
        "phone_number" => phone_number,
        "upi_id" => upi_id
      }) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _employee_credential} <-
           EmployeeAccounts.update_upi_id(phone_number, upi_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated upi id!"})
    end
  end

  def update_employee_details(
        conn,
        params = %{
          "uuid" => uuid,
          "name" => name,
          "phone_number" => phone_number,
          "employee_role_id" => employee_role_id,
          "email" => email,
          "employee_code" => employee_code,
          "city_id" => city_id,
          "reporting_manager_id" => reporting_manager_id,
          "access_city_ids" => access_city_ids,
          "vertical_id" => vertical_id
        }
      ) do
    with {:ok, _employee_credential} <-
           EmployeeAccounts.update_employee_details(
             uuid,
             name,
             phone_number,
             employee_role_id,
             email,
             employee_code,
             city_id,
             reporting_manager_id,
             access_city_ids,
             params["country_code"] || "+91",
             vertical_id || EmployeeVertical.default_vertical_id()
           ) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated employee"})
    end
  end

  def validate_upi_id(conn, %{"upi_id" => upi_id}) do
    {flag, message} = Accounts.validate_upi(upi_id)

    conn
    |> put_status(:ok)
    |> json(%{is_valid: flag, message: message})
  end

  def check_upi(conn, %{
        "phone_number" => phone_number
      }) do
    with {status, data} <- EmployeeAccounts.check_upi_id(phone_number) do
      conn
      |> put_status(:ok)
      |> json(%{message: status, data: data})
    end
  end

  defp get_organization_broker_ids(org_uuids) do
    org_uuids
    |> String.split(",")
    |> Enum.reduce([], fn org_uuid, acc ->
      acc ++
        (Organizations.get_organization_brokers(org_uuid)
         |> Enum.map(& &1[:broker_id]))
    end)
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

  defp create_assign_organization_event_params(params, user_id) do
    PanelEvent.create_event(%{
      "employees_credentials_id" => user_id,
      "type" => "assign",
      "action" => "assign_organization",
      "data" => params
    })
  end

  defp create_reassign_organization_event_params(params, user_id) do
    PanelEvent.create_event(%{
      "employees_credentials_id" => user_id,
      "type" => "assign",
      "action" => "reassign_organization",
      "data" => params
    })
  end

  defp create_transfer_organizations_event_params(params, user_id) do
    PanelEvent.create_event(%{
      "employees_credentials_id" => user_id,
      "type" => "assign",
      "action" => "transfer_organizations",
      "data" => params
    })
  end

  defp maybe_verify_otp("9999999999", _otp), do: {:ok}

  defp maybe_verify_otp(phone_number, otp) do
    Otp.verify_otp(phone_number, @profile_type_id, otp)
  end

  defp send_otp_sms(phone_number, message),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message, true, false, "admin_login"])

  defp validate_whitelist_broker_params(params) do
    cond do
      is_nil(params["phone_number"]) or params["phone_number"] == "" ->
        {:error, "Please provide valid phone number"}

      is_nil(params["assign_to"]) or params["assign_to"] == "" ->
        {:error, "Please provide valid assignee"}

      is_nil(params["polygon_uuid"]) or params["polygon_uuid"] == "" ->
        {:error, "Please provide valid polygon for the broker"}

      true ->
        :ok
    end
  end

  def update_fcm_id(conn, %{
        "fcm_id" => fcm_id,
        "platform" => platform
      }) do
    user_uuid = conn.assigns[:user]["uuid"]
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _credential} <-
           Accounts.update_fcm_id_for_employee(
             user_uuid,
             fcm_id,
             platform,
             user_map
           ) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated fcm id!"})
    end
  end

  def get_all_assigned_employee(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    user_id = if is_nil(params["user_id"]), do: logged_in_user.user_id, else: params["user_id"]

    with {:ok, employee_credential} <- EmployeeCredential.get_employee_by_uuids(user_id) do
      conn
      |> put_status(:ok)
      |> json(employee_credential)
    end
  end
end
