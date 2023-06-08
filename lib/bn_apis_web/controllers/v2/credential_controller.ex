defmodule BnApisWeb.V2.CredentialController do
  use BnApisWeb, :controller

  alias BnApis.Accounts
  alias BnApis.Accounts.ProfileType
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Helpers.{Otp, Token, Connection}
  alias BnApis.Organizations.Broker

  action_fallback(BnApisWeb.FallbackController)

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
         {:ok} <- Otp.verify_otp(phone_number, profile_type_id, otp),
         {:ok} <- Broker.is_whitelisting_approved(phone_number) do
      case Accounts.verify_otp_sign_up_status?(phone_number, country_code) do
        {:ok, result} when result in ~w(signup_incomplete panel_signup_incomplete)a ->
          with {:ok, signup_token} <- Otp.generate_signup_token(phone_number, country_code, profile_type_id),
               credential = Accounts.get_active_credential_by_phone(phone_number, country_code) do
            profile_details =
              if not is_nil(credential) do
                Token.create_token_data(credential.uuid, profile_type_id, true)["profile"]
              else
                nil
              end

            conn
            |> put_status(:ok)
            |> json(%{signup_completed: false, user_id: signup_token, profile: profile_details})
          end

        {:ok, token} ->
          profile = Token.get_token_data(token, profile_type_id, true) |> Map.take(["profile"])

          conn
          |> put_status(:ok)
          |> render(BnApisWeb.CredentialView, "verify_otp.json", %{token: token, profile: profile})
      end
    else
      {:otp_error, %{message: message}} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})

      {:error, message} ->
        conn |> put_status(:unprocessable_entity) |> json(%{message: message})
    end
  end

  def validate(conn, _params) do
    session_token =
      if Connection.bearer_auth?(conn) do
        Connection.bearer_auth_creds(conn)
      end

    profile_type_id = ProfileType.broker().id
    profile = Token.get_token_data(session_token, profile_type_id, true) |> Map.take(["profile"])

    result = %{session_token: session_token} |> Map.merge(profile)

    conn
    |> put_status(:ok)
    |> json(result)
  end
end
