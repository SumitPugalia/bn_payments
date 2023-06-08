defmodule BnApisWeb.V1.CredentialController do
  use BnApisWeb, :controller

  alias BnApis.{Accounts, Organizations}
  alias BnApis.Accounts.ProfileType
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Otp, Token, Connection, ExternalApiHelper}

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
         {:ok, %{otp: otp, otp_requested_count: stored_otp_request_count, max_count_allowed: otp_request_limit}} <-
           Otp.generate_otp_tokens(phone_number, profile_type_id) do
      message =
        "OTP is #{otp} for the Broker App registration. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

      if invited do
        case Accounts.mark_invites_as_tried(phone_number, country_code) do
          {0, _} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{message: "Error occured, please try again!"})

          {_count, _updates} ->
            phone_number
            |> Phone.append_country_code(country_code)
            |> send_otp_sms(message)

            Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

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
        phone_number
        |> Phone.append_country_code(country_code)
        |> send_otp_sms(message)

        Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

        conn
        |> put_status(:ok)
        |> json(%{
          request_id: request_id,
          whitelisted: whitelisted,
          otp_requested_count: stored_otp_request_count,
          max_count_allowed: otp_request_limit
        })
      end
    else
      {:otp_error, error_message} ->
        conn |> put_status(:unprocessable_entity) |> json(error_message)

      {:error, message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})
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
         {:ok, %{otp: otp, otp_requested_count: stored_otp_request_count, max_count_allowed: otp_request_limit}} <-
           Otp.generate_otp_tokens(phone_number, profile_type_id) do
      message =
        "OTP is #{otp} for the Broker App registration. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +919373200897 to report anyone who asks for your OTP."

      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message, otp_over_call)

      Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

      conn
      |> put_status(:ok)
      |> json(%{
        request_id: request_id,
        otp_requested_count: stored_otp_request_count,
        max_count_allowed: otp_request_limit
      })
    else
      {:otp_error, error_message} ->
        conn |> put_status(:unprocessable_entity) |> json(error_message)

      {:error, message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})
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
          with {:ok, signup_token} <- Otp.generate_signup_token(phone_number, country_code, profile_type_id),
               credential = Accounts.get_active_credential_by_phone(phone_number, country_code) do
            profile_details =
              if not is_nil(credential) do
                Token.create_token_data(credential.uuid, profile_type_id, false)["profile"]
              else
                nil
              end

            conn
            |> put_status(:ok)
            |> json(%{signup_completed: false, user_id: signup_token, profile: profile_details})
          end

        {:ok, token} ->
          profile = Token.get_token_data(token, profile_type_id) |> Map.take(["profile"])

          conn
          |> put_status(:ok)
          |> render(BnApisWeb.CredentialView, "verify_otp.json", %{token: token, profile: profile})
      end
    else
      {:otp_error, %{message: message}} ->
        {:error, message}

      {:error, message} ->
        {:error, message}
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

    with {:ok, phone_number, country_code} <- Otp.verify_signup_token(signup_token, profile_type_id),
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
      |> render(BnApisWeb.CredentialView, "signup.json", %{token: token, profile: profile})
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

    with {:ok, phone_number, country_code} <- Otp.verify_signup_token(signup_token, profile_type_id),
         {:ok, {credential}} <-
           Accounts.signup_user(params |> Map.merge(%{"phone_number" => phone_number, "country_code" => country_code})),
         Otp.delete_signup_token(signup_token),
         Token.destroy_all_user_tokens(credential.id, profile_type_id),
         {:ok, token} <- Token.initialize_broker_token(credential.uuid) do
      profile = Token.get_token_data(token, profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.CredentialView, "signup.json", %{token: token, profile: profile})
    end
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile_type_id = ProfileType.broker().id

    session_data = Token.get_token_data(session_token, profile_type_id)
    profile = Map.take(session_data, ["profile"])

    result =
      %{session_token: session_token}
      |> Map.merge(profile)

    conn
    |> put_status(:ok)
    |> json(result)
  end

  defp send_otp_sms(phone_number, message, _otp_over_call \\ "false")

  defp send_otp_sms(phone_number, _message, _otp_over_call = "true"),
    do: ExternalApiHelper.send_otp_over_call(phone_number)

  defp send_otp_sms(phone_number, message, _otp_over_call),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message, true, true, "broker_login"])
end
