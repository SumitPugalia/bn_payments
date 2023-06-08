defmodule BnApisWeb.V1.DeveloperPocCredentialController do
  use BnApisWeb, :controller

  alias BnApis.Accounts
  alias BnApis.Accounts.ProfileType
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Otp, Token, Connection}
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Helpers.Utils

  action_fallback(BnApisWeb.FallbackController)

  @profile_type_id ProfileType.developer_poc().id

  @doc """
    Generates OTP & request_id
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
         {:ok, _developer_credential} <-
           Accounts.check_developer_poc_user_present(phone_number, country_code),
         {:ok, _mapping} <-
           DeveloperPocCredential.fetch_developer_poc_associated_to_story(
             phone_number,
             country_code
           ),
         {:ok, %{otp: otp}} <-
           Otp.generate_otp_tokens(phone_number, @profile_type_id) do
      message =
        "OTP is #{otp} for the Developer App login. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +917768822261 to report anyone who asks for your OTP."

      # Sending OTP
      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message)

      Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

      conn
      |> put_status(:ok)
      |> json(%{request_id: request_id})
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
         {:ok, %{otp: otp}} <-
           Otp.generate_otp_tokens(phone_number, @profile_type_id),
         message =
           "OTP is #{otp} for the Developer App login. Valid for #{Otp.get_otp_life()} minutes. DO NOT SHARE THIS OTP with any BrokerNetwork Employee or Channel Partner. Please call +917768822261 to report anyone who asks for your OTP." do
      phone_number
      |> Phone.append_country_code(country_code)
      |> send_otp_sms(message)

      Exq.enqueue(Exq, "send_otp_sms", BnApis.SendOtpSmsWorker, [phone_number, otp])

      conn
      |> put_status(:ok)
      |> json(%{
        request_id: request_id
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
         {:ok, developer_poc_credential} <-
           Accounts.check_developer_poc_user_present(phone_number, country_code),
         {:ok} <- Otp.verify_otp(phone_number, @profile_type_id, otp),
         Token.destroy_all_user_tokens(
           developer_poc_credential.id,
           @profile_type_id
         ),
         {:ok, token} <-
           Token.initialize_developer_poc_token(developer_poc_credential) do
      profile =
        Token.get_token_data(token, @profile_type_id)
        |> Map.take(["profile", "story_uuid", "story_name", "project_logo_url"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.DeveloperPocCredentialView, "verify_otp.json", %{
        token: token,
        profile: profile
      })
    end
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      else
        conn |> get_req_header("session-token") |> List.first()
      end

    profile =
      Token.get_token_data(session_token, @profile_type_id)
      |> Map.take(["profile", "story_uuid", "story_name", "project_logo_url"])

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.DeveloperPocCredentialView, "signup.json", %{
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
    user_id = Connection.get_developer_logged_in_user(conn)[:user_id]

    with {:ok, _del} <- Token.destroy_all_user_tokens(user_id, @profile_type_id) do
      conn
      |> put_status(:ok)
      |> json(%{
        message: "You have been signed out from all sessions successfully"
      })
    end
  end

  defp send_otp_sms(phone_number, message),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message, true, true, "developer_poc_login"])

  def update_fcm_id(conn, %{
        "fcm_id" => fcm_id,
        "platform" => platform
      }) do
    logged_in_user = Connection.get_developer_logged_in_user(conn)
    user_uuid = logged_in_user[:uuid]
    user_map = Utils.get_user_map(logged_in_user)

    with {:ok, _dev_poc_cred} <-
           Accounts.update_fcm_id_for_developer_poc(
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
end
