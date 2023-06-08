defmodule BnApisWeb.CredentialController do
  use BnApisWeb, :controller

  alias BnApis.Accounts.Credential
  alias BnApis.{Accounts, Organizations}
  alias BnApis.Accounts.ProfileType
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone

  alias BnApis.Helpers.{
    Otp,
    Token,
    Connection,
    ExternalApiHelper,
    Connection,
    Utils
  }

  alias BnApis.Posts.{RentalMatch, ResaleMatch}

  action_fallback(BnApisWeb.FallbackController)

  @doc """
    Generates OTP & request_id (For whitelisted or Invited numbers)
    Sends OTP to the provided number using SMS Gateway
    @param {string} phone_number [to be registered]
    returns {
      {string} request_id [SecureRandom string]
    }
  """
  def send_otp(conn, params) do
    profile_type_id = ProfileType.broker().id
    # remove request_id in future
    request_id = SecureRandom.urlsafe_base64(32)

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %{invited: invited, invites: invites, whitelisted: whitelisted} <-
           Accounts.whitelisted_or_invited?(phone_number, country_code),
         {:ok,
          %{
            otp: otp,
            otp_requested_count: stored_otp_request_count,
            max_count_allowed: otp_request_limit
          }} <- Otp.generate_otp_tokens(phone_number, profile_type_id) do
      message =
        "OTP is #{otp} for the Broker App registration. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

      if invited do
        case Accounts.mark_invites_as_tried(phone_number, country_code) do
          {0, _} ->
            {:error, "Error occured, please try again!"}

          {_count, _updates} ->
            # Sending OTP
            phone_number
            |> Phone.append_country_code(country_code)
            |> send_otp_sms(message)

            conn
            |> put_status(:ok)
            |> render(BnApisWeb.CredentialView, "invited_otp_respose.json", %{
              request_id: request_id,
              invites: invites,
              whitelisted: whitelisted,
              otp_requested_count: stored_otp_request_count,
              max_count_allowed: otp_request_limit
            })
        end
      else
        # Sending OTP
        phone_number
        |> Phone.append_country_code(country_code)
        |> send_otp_sms(message)

        conn
        |> put_status(:ok)
        |> json(%{
          request_id: request_id,
          otp_requested_count: stored_otp_request_count,
          max_count_allowed: otp_request_limit
        })
      end
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
  def resend_otp(conn, params) do
    profile_type_id = ProfileType.broker().id

    {request_id, otp_over_call} = {params["request_id"], params["otp_over_call"] || "false"}

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         %{invited: _invited, invites: _invites, whitelisted: _whitelisted} <-
           Accounts.whitelisted_or_invited?(phone_number, country_code),
         {:ok,
          %{
            otp: otp,
            otp_requested_count: stored_otp_request_count,
            max_count_allowed: otp_request_limit
          }} <- Otp.generate_otp_tokens(phone_number, profile_type_id) do
      message =
        "OTP is #{otp} for the Broker App registration. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message, otp_over_call)

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
    Marks user phone_number as verified.
    Logout of other sessions.
    Sets current User session_token and signin.
    if already signed up, return session_token

    @param {string} phone_number [registered one]
    @param {string} otp [received on phone_number]
    returns {
      {bool} success,
      {bool} opt_expired,
    }

    TODO: write test for all flows

    POSSIBLE FLOWS:
    1. Fresh Invite
    2. Fresh Signup
    3. Re-Login
    4. Invited for Re-activating account in same org
    5. Invited to join new org
  """
  def verify_otp(conn, %{"otp" => otp} = params) do
    profile_type_id = ProfileType.broker().id

    with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
         {:ok} <- Otp.verify_otp(phone_number, profile_type_id, otp) do
      case Accounts.verify_otp_sign_up_status?(phone_number, country_code) do
        {:ok, result} when result in ~w(signup_incomplete panel_signup_incomplete)a ->
          with {:ok, signup_token} <-
                 Otp.generate_signup_token(phone_number, country_code, profile_type_id),
               credential = Accounts.get_active_credential_by_phone(phone_number, country_code) do
            profile_details =
              if not is_nil(credential) do
                Token.create_token_data(credential.uuid, profile_type_id, false)[
                  "profile"
                ]
              else
                nil
              end

            conn
            |> put_status(:ok)
            |> json(%{
              signup_completed: false,
              user_id: signup_token,
              profile: profile_details
            })
          end

        {:ok, token} ->
          token_data = Token.get_token_data(token, profile_type_id)
          profile = token_data |> Map.take(["profile"])

          app_type = conn |> get_req_header("x-app-type") |> List.first()
          Accounts.update_app_type(token_data["uuid"], app_type)

          conn
          |> put_status(:ok)
          |> render(BnApisWeb.CredentialView, "verify_otp.json", %{
            token: token,
            profile: profile
          })
      end
    else
      {:otp_error, error_response} ->
        conn |> put_status(:unprocessable_entity) |> json(error_response)

      {:error, message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})
    end
  end

  @doc """
    Signup user for Invited Number
    Requires:
      {
        name: name,
        user_id: <last request user_id>,
        organization_id: selected_org_id,
      }
    returns {
      {string} message
    }
  """
  def signup(
        conn,
        params = %{
          "name" => _name,
          "organization_id" => org_id,
          "user_id" => signup_token
          # "profile_image" => profile_image, #OPTIONAL
          # "fcm_id" => fcm_id, #OPTIONAL
        }
      ) do
    profile_type_id = ProfileType.broker().id
    params = params |> Map.merge(%{"organization_id" => org_id |> String.to_integer()})

    with {:ok, phone_number, country_code} <-
           Otp.verify_signup_token(signup_token, profile_type_id),
         {:ok, {credential}} <-
           Accounts.signup_invited_user(
             params
             |> Map.merge(%{"phone_number" => phone_number, "country_code" => country_code})
           ),
         Organizations.auto_assign_broker(org_id, credential.broker_id),
         Otp.delete_signup_token(signup_token),
         Token.destroy_all_user_tokens(credential.id, profile_type_id),
         {:ok, token} <- Token.initialize_broker_token(credential.uuid) do
      profile = Token.get_token_data(token, profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "signup.json", %{
        token: token,
        profile: profile
      })
    end
  end

  def signup(
        conn,
        params = %{
          "name" => _name,
          "organization_name" => _organization_name,
          "user_id" => signup_token
          # "profile_image" => profile_image,
          # "fcm_id" => fcm_id
        }
      ) do
    profile_type_id = ProfileType.broker().id

    with {:ok, phone_number, country_code} <-
           Otp.verify_signup_token(signup_token, profile_type_id),
         {:ok, {credential}} <-
           Accounts.signup_user(
             params
             |> Map.merge(%{"phone_number" => phone_number, "country_code" => country_code})
           ),
         Otp.delete_signup_token(signup_token),
         Token.destroy_all_user_tokens(credential.id, profile_type_id),
         {:ok, token} <- Token.initialize_broker_token(credential.uuid) do
      profile = Token.get_token_data(token, profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "signup.json", %{
        token: token,
        profile: profile
      })
    end
  end

  @doc """
    Update FCM id
    Requires:
      {
        fcm_id: <fcm_id>,
      }
    returns {
      {string} message
    }
  """
  def update_fcm_id(conn, params) do
    user_uuid = conn.assigns[:user]["uuid"]
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _credential} <-
           Accounts.update_fcm_id(
             user_uuid,
             params["fcm_id"],
             params["platform"],
             user_map
           ) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated fcm id!"})
    end
  end

  def update_apns_id(conn, %{
        "apns_id" => apns_id
      }) do
    user_uuid = conn.assigns[:user]["uuid"]
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _credential} <- Accounts.update_apns_id(user_uuid, apns_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated apns id!"})
    end
  end

  def update_upi_id(conn, %{
        "upi_id" => upi_id
      }) do
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)
    user_uuid = conn.assigns[:user]["uuid"]

    with {:ok, _credential} <- Accounts.update_upi_id(user_uuid, upi_id, user_map) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Successfully updated upi id!"})
    end
  end

  def validate_upi_id(conn, %{"upi_id" => upi_id}) do
    {flag, message} = Accounts.validate_upi(upi_id)

    conn
    |> put_status(:ok)
    |> json(%{is_valid: flag, message: message})
  end

  def check_upi(conn, _params) do
    user_uuid = conn.assigns[:user]["uuid"]

    with {status, data} <- Accounts.check_upi_id(user_uuid) do
      conn
      |> put_status(:ok)
      |> json(%{message: status, data: data})
    end
  end

  def validate_gstin(conn, %{"gstin" => gstin}) do
    {flag, message} = Accounts.validate_gst(gstin)

    conn
    |> put_status(:ok)
    |> json(%{is_valid: flag, message: message})
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile_type_id = ProfileType.broker().id

    profile =
      Token.get_token_data(session_token, profile_type_id)
      |> Map.take(["profile"])

    result = %{session_token: session_token} |> Map.merge(profile)

    conn
    |> put_status(:ok)
    |> json(result)
  end

  @doc """
  Applozic server will call accessToken URL set at this route with userId and token as password

  API Response should be in text format.
  returns:
  true - If user is authenticated
  false - If user is not authenticated
  """
  def authenticate_chat_token(
        conn,
        _params = %{
          "userId" => user_uuid,
          "token" => chat_token
        }
      ) do
    with {:ok, is_valid} <-
           Accounts.authenticate_chat_token(user_uuid, chat_token) do
      send_resp(conn, :ok, "#{is_valid}")
    end
  end

  @doc """
    Signout from all sessions.

    returns {
      {string} message
    }
  """
  def signout(conn, _params) do
    profile_type_id = ProfileType.broker().id
    user_id = conn.assigns[:user]["user_id"]
    logged_in_user = Connection.get_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_user)

    with Accounts.remove_user_tokens(user_id, user_map),
         {:ok, _del} <- Token.destroy_all_user_tokens(user_id, profile_type_id) do
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
      "user_id" => credential_uuid,
      }
  """
  def promote_user(conn, params = %{"user_uuid" => _credential_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, message} <- Accounts.promote_user(logged_in_user, params) do
      trigger_team_notification(params["user_uuid"])

      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  @doc """
    Demote user to Chottus role.
    ONLY ADMINS are allowed to take this action

    Required  %{
      "user_id" => credential_uuid,
      }
  """
  def demote_user(conn, params = %{"user_uuid" => _credential_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, message} <- Accounts.demote_user(logged_in_user, params) do
      trigger_team_notification(params["user_uuid"])

      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  @doc """
    Remove user.
    ONLY ADMINS are allowed to take this action

    Required  %{
      "user_id" => credential_uuid,
      }
  """
  def remove_user(conn, params = %{"user_uuid" => credential_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    successor_uuid = Map.get(params, "successor_uuid", credential_uuid)

    with {:ok, message} <- Credential.remove_user(logged_in_user, credential_uuid, successor_uuid) do
      trigger_team_notification(params["user_uuid"])

      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  def leave_user(conn, %{"successor_uuid" => successor_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    with {:ok, message} <- Credential.leave_user(logged_in_user, successor_uuid) do
      conn
      |> put_status(:ok)
      |> json(%{message: message})
    end
  end

  def leave_user(_conn, _), do: {:error, "Invalid params"}

  def block(conn, %{"user_uuid" => blockee_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)

    {status, result} =
      BnApis.Repo.transaction(fn ->
        with(
          {:ok, blockee_id} <- Accounts.uuid_to_id(blockee_uuid),
          # mark all matches as blocked
          {_, nil} <-
            RentalMatch.mark_matches_against_each_other_as_blocked(
              logged_in_user[:user_id],
              blockee_id
            ),
          {_, nil} <-
            ResaleMatch.mark_matches_against_each_other_as_blocked(
              logged_in_user[:user_id],
              blockee_id
            ),
          {:ok, _} <-
            BnApis.Accounts.BlockedUser.block(
              logged_in_user[:user_id],
              blockee_id
            )
        ) do
          %{message: "Successfully blocked"}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            BnApis.Repo.rollback(inspect(changeset.errors))

          {:error, error_message} ->
            BnApis.Repo.rollback(error_message)
        end
      end)

    if status == :error do
      conn |> put_status(:unprocessable_entity) |> json(%{message: result})
    else
      conn |> put_status(:ok) |> json(result)
    end
  end

  def unblock(conn, %{"user_uuid" => blockee_uuid}) do
    logged_in_user = Connection.get_logged_in_user(conn)
    {:ok, blockee_id} = Accounts.uuid_to_id(blockee_uuid)
    BnApis.Accounts.BlockedUser.unblock(logged_in_user[:user_id], blockee_id)
    conn |> put_status(:ok) |> json(%{message: "Successfully unblocked"})
  end

  def get_text(conn, params) do
    phone_number = params["From"] || params["CallFrom"]
    profile_type_id = ProfileType.broker().id

    {:ok, phone_number, _country_code} =
      Phone.parse_phone_number(%{
        "phone_number" => phone_number,
        "country_code" => params["country_code"]
      })

    %{otp: stored_otp, retry_count: _retry_count} = Otp.get_otp(phone_number, profile_type_id)

    conn |> put_status(:ok) |> text(ivr_text(stored_otp))
  end

  defp format_otp(otp) do
    otp
    |> String.split("")
    |> Enum.join(". ")
  end

  defp ivr_text(otp) when is_nil(otp), do: nil

  defp ivr_text(otp) do
    formatted_otp = otp |> format_otp()

    "Your Broker Network verification code is #{formatted_otp} I repeat #{formatted_otp}"
  end

  defp trigger_team_notification(user_uuid) do
    Exq.enqueue(
      Exq,
      "team_notification",
      BnApis.TeamNotificationWorker,
      [user_uuid],
      max_retries: 0
    )
  end

  defp send_otp_sms(phone_number, message, _otp_over_call \\ "false")

  defp send_otp_sms(phone_number, _message, _otp_over_call = "true"),
    do: ExternalApiHelper.send_otp_over_call(phone_number)

  defp send_otp_sms(phone_number, message, _otp_over_call),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message])
end
