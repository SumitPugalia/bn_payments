defmodule BnApisWeb.DeveloperCredentialController do
  use BnApisWeb, :controller

  alias BnApis.Accounts
  alias BnApis.Accounts.ProfileType
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Otp, Token, Connection, Time}
  alias BnApis.Developers

  @profile_type_id ProfileType.developer().id

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
           Accounts.is_developer_user_present?(phone_number, country_code),
         {:ok, %{otp: otp}} <-
           Otp.generate_otp_tokens(phone_number, @profile_type_id) do
      message = "OTP is #{otp} for the Developer App login. Valid for #{Otp.get_otp_life()} minutes. Do not share this OTP to anyone for security reasons."

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
         message = "OTP is #{otp} for the Developer App login. Valid for #{Otp.get_otp_life()} minutes. Do not share this OTP to anyone for security reasons." do
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
         {:ok, developer_credential} <-
           Accounts.is_developer_user_present?(phone_number, country_code),
         {:ok} <- Otp.verify_otp(phone_number, @profile_type_id, otp),
         Token.destroy_all_user_tokens(
           developer_credential.id,
           @profile_type_id
         ),
         {:ok, token} <-
           Token.initialize_developer_token(developer_credential.uuid) do
      profile = Token.get_token_data(token, @profile_type_id) |> Map.take(["profile"])

      conn
      |> put_status(:ok)
      |> render(BnApisWeb.DeveloperCredentialView, "verify_otp.json", %{
        token: token,
        profile: profile
      })
    end
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile =
      Token.get_token_data(session_token, @profile_type_id)
      |> Map.take(["profile"])

    conn
    |> put_status(:ok)
    |> render(BnApisWeb.DeveloperCredentialView, "signup.json", %{
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

  def create_site_visits(conn, params) do
    logged_in_user = Connection.get_developer_logged_in_user(conn)
    reported_by_id = logged_in_user[:user_id]
    params = process_site_visit_params(params, reported_by_id)
    params |> Developers.create_site_visits()
    conn |> put_status(:ok) |> json(%{message: "Successfully created"})
  end

  def process_site_visit_params(params, reported_by_id) do
    params =
      if params["site_visits"] |> is_list(),
        do: params["site_visits"],
        else: params["site_visits"] |> Poison.decode!()

    params
    |> Enum.map(fn param ->
      naive_time_of_visit = param["time_of_visit"] |> Time.epoch_to_naive()

      visited_by =
        Accounts.get_credential_by_uuid(param["broker_credential_uuid"]) ||
          Accounts.get_active_credential_by_phone(param["broker_phone_number"], "+91")

      project_info = Developers.get_project_by_uuid(param["project_uuid"])

      broker_phone_number =
        param["broker_phone_number"]
        |> Accounts.process_site_visit_phone(
          param["broker_name"],
          project_info.name
        )

      %{
        visited_by_id: (Map.has_key?(visited_by || %{}, :id) && visited_by.id) || nil,
        old_visited_by: (Map.has_key?(visited_by || %{}, :id) && visited_by.id) || nil,
        old_organization_id: Map.get(visited_by || %{}, :organization_id),
        reported_by_id: reported_by_id,
        time_of_visit: naive_time_of_visit,
        project_id: project_info.id,
        broker_credential_uuid: param["broker_credential_uuid"],
        broker_phone_number: broker_phone_number,
        broker_name: param["broker_name"],
        broker_email: param["broker_email"],
        lead_reference: "#{param["lead_reference"]}",
        lead_reference_name: param["lead_reference_name"],
        lead_reference_email: param["lead_reference_email"]
      }
    end)
  end

  defp send_otp_sms(phone_number, message),
    do: Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [phone_number, message, true, true, "developer_login"])
end
