defmodule BnApis.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.{Organizations, Posts}

  alias BnApis.Accounts.{
    Credential,
    ProfileType,
    WhitelistedNumber,
    Invite,
    InviteStatus,
    EmployeeCredential,
    DeveloperCredential,
    ColorCode,
    DeveloperPocCredential
  }

  alias BnApis.Helpers.{
    Token,
    S3Helper,
    Time,
    ApplicationHelper,
    ExternalApiHelper,
    AuditedRepo,
    Utils
  }

  alias BnApis.Notifications.Request
  alias BnApis.Organizations.{Broker, Organization}

  @day_seconds 86400
  @india_country_code "+91"

  @doc """
  Gets a single credential.

  Raises `Ecto.NoResultsError` if the Credential does not exist.

  ## Examples

      iex> get_credential!(123)
      %Credential{}

      iex> get_credential!(456)
      ** (Ecto.NoResultsError)

  """
  def get_credential!(id), do: Repo.get!(Credential, id)
  def get_credential(id), do: Repo.get(Credential, id)

  def get_credential_by_uuid(uuid) do
    Credential.get_by_uuid_query(uuid) |> Repo.one()
  end

  def get_broker_by_user_id(user_id) do
    credential = Credential |> Repo.get(user_id) |> Repo.preload([:broker], force: true)

    credential.broker
  end

  @doc """
  DB constraint of not having more than one active account on phone_number
  """
  def get_active_credential_by_phone(phone_number, country_code) do
    case Repo.get_by(Credential, phone_number: phone_number, country_code: country_code, active: true) do
      {:error, _error_message} -> nil
      credential -> credential
    end
  end

  def process_site_visit_phone(phone_number, broker_name, project_name) do
    if phone_number == "" or is_nil(phone_number) do
      phone_number
    else
      # send sms if credential is not found
      if get_active_credential_by_phone(phone_number, @india_country_code) do
        phone_number
      else
        WhitelistedNumber.create_or_fetch_whitelisted_number(phone_number, @india_country_code)
        # also send sms to broker and support team
        message = ApplicationHelper.get_broker_message()

        support_team_message =
          ApplicationHelper.get_support_team_message(
            broker_name,
            phone_number,
            project_name
          )

        Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [
          phone_number,
          message,
          false
        ])

        Exq.enqueue(Exq, "send_sms", BnApis.SendSmsWorker, [
          ApplicationHelper.get_customer_support_number(),
          support_team_message,
          false
        ])

        phone_number
      end
    end
  end

  def uuid_to_id(uuid) do
    case Credential.get_by_uuid_query(uuid) |> Repo.one() do
      nil ->
        {:error, "User not found!"}

      credential ->
        {:ok, credential.id}
    end
  end

  def is_test_post?(logged_in_user_id, assigned_user_id) do
    get_credential(logged_in_user_id).test_user ||
      get_credential(assigned_user_id).test_user
  end

  @doc """
  Creates a credential.
  ## Examples
      iex> create_credential(%{field: value})
      {:ok, %Credential{}}
      iex> create_credential(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_credential(attrs, user_map) do
    # remove_user_dnd(attrs["phone_number"] || attrs[:phone_number])
    %Credential{}
    |> Credential.changeset(attrs)
    |> AuditedRepo.insert(user_map)
  end

  def remove_user_dnd(phone_number) do
    Exq.enqueue(Exq, "dnd_removal", RemoveDNDWorker, [phone_number])
  end

  def mark_invites_as_tried(phone_number, country_code) do
    Invite.mark_invites_as_tried_changeset(phone_number, country_code)
    |> Repo.update_all([], [])
  end

  def refresh_chat_auth_token(credential, user_map) do
    token = SecureRandom.urlsafe_base64(64)
    credential |> Credential.chat_auth_token_changeset(token) |> AuditedRepo.update(user_map)
  end

  def remove_user_tokens(user_id, user_map) do
    case get_credential!(user_id) do
      nil ->
        {:error, "User not found"}

      credential ->
        credential
        |> Credential.remove_user_tokens_changeset()
        |> AuditedRepo.update(user_map)
    end
  end

  @doc """
  Used in Verify Token
  """

  def verify_otp_sign_up_status?(phone_number, country_code) do
    user_map = Utils.get_whitelisted_or_invited_broker_user_map(phone_number, country_code)
    profile_type_id = ProfileType.broker().id

    case get_active_credential_by_phone(phone_number, country_code) do
      nil ->
        {:ok, :signup_incomplete}

      credential ->
        cond do
          credential.auto_created == true ->
            # whatsapp seeding signup flow
            {:ok, :signup_incomplete}

          credential.panel_auto_created == true ->
            {:ok, :panel_signup_incomplete}

          true ->
            Token.destroy_all_user_tokens(credential.id, profile_type_id)
            refresh_chat_auth_token(credential, user_map)

            credential
            |> Credential.update_installed_flag(true)
            |> AuditedRepo.update(user_map)

            Token.initialize_broker_token(credential.uuid)
        end
    end
  end

  def whitelisted_or_invited?(phone_number, country_code) do
    # Invite has more weightage than whitelisted!

    whitelist = Repo.get_by(WhitelistedNumber, phone_number: phone_number, country_code: country_code)

    invites =
      Invite.new_invites_query(phone_number, country_code)
      |> Invite.invite_select_query()
      |> Repo.all()
      |> Enum.map(&%{&1 | sent_date: Time.naive_to_epoch_in_sec(&1.sent_date)})

    case get_active_credential_by_phone(phone_number, country_code) do
      nil ->
        cond do
          not is_nil(whitelist) and invites |> length > 0 ->
            %{invited: true, invites: invites, whitelisted: true}

          invites |> length != 0 ->
            %{invited: true, invites: invites, whitelisted: false}

          not is_nil(whitelist) ->
            %{invited: false, invites: [], whitelisted: true}

          true ->
            {:error, "Sorry, You are not allowed to use this app!"}
        end

      %Credential{panel_auto_created: true} ->
        if invites |> length != 0,
          do: %{invited: true, invites: invites, whitelisted: true},
          else: %{invited: false, invites: [], whitelisted: true}

      _credential ->
        %{invited: false, invites: [], whitelisted: true}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking broker changes.

  ## Examples

      iex> change_broker(broker)
      %Ecto.Changeset{source: %Broker{}}

  """

  def signup_user(params = %{"phone_number" => phone_number, "country_code" => country_code}) do
    user_map = Utils.get_whitelisted_or_invited_broker_user_map(phone_number, country_code)

    case get_active_credential_by_phone(phone_number, country_code) do
      nil ->
        Organizations.signup_user(params, user_map)

      credential ->
        cond do
          credential.auto_created == true ->
            # whatsapp signup flow
            Organizations.whatsapp_signup_user(params, credential, user_map)

          credential.panel_auto_created == true ->
            Organizations.whatsapp_signup_user(params, credential, user_map)

          credential.active == true ->
            {:error, "You have already signed up. Try login!"}

          true ->
            {:error, "Unknown error occured!"}
        end
    end
  end

  def signup_invited_user(
        params = %{
          "phone_number" => phone_number,
          "country_code" => country_code,
          "organization_id" => selected_org_id
        }
      ) do
    user_map = Utils.get_whitelisted_or_invited_broker_user_map(phone_number, country_code)

    case Credential
         |> Repo.get_by(
           phone_number: phone_number,
           country_code: country_code,
           organization_id: selected_org_id
         ) do
      nil ->
        # Check if invited to this organization_id?
        case Invite.check_invitation(phone_number, country_code, selected_org_id) do
          nil ->
            {:error, "Sorry, you are not invited to this organization!"}

          invite ->
            Organizations.signup_invited_user(params, invite, user_map)
        end

      %{active: false} = credential ->
        case Invite.check_invitation(phone_number, country_code, selected_org_id) do
          nil ->
            {:error, "Sorry, you are not invited to this organization!"}

          invite ->
            {:ok, credential} = credential |> Credential.activate_changeset() |> AuditedRepo.update(user_map)

            # Change Invite to Accepted
            invite
            |> Invite.mark_invite_as_changeset(InviteStatus.accepted().id)
            |> Repo.update!()

            # Cancel rest of the invites
            Invite.cancel_other_invites(phone_number, country_code)
            {:ok, {credential}}
        end

      %{active: true} ->
        {:error, "You have already signed up. Try login!"}

      _ ->
        {:error, "Unknown error occured!"}
    end
  end

  def update_fcm_id(user_uuid, fcm_id, platform, user_map) do
    case get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        credential |> Credential.fcm_changeset(fcm_id, platform) |> AuditedRepo.update(user_map)
    end
  end

  def update_fcm_id_for_employee(user_uuid, fcm_id, platform, user_map) do
    case EmployeeCredential.fetch_employee(user_uuid) do
      nil ->
        {:error, "User not found"}

      emp_credential ->
        emp_credential |> EmployeeCredential.fcm_changeset(fcm_id, platform) |> AuditedRepo.update(user_map)
    end
  end

  def update_fcm_id_for_developer_poc(user_uuid, fcm_id, platform, user_map) do
    case get_developer_poc_credential_by_uuid(user_uuid) do
      nil -> {:error, :not_found}
      dev_poc_cred -> DeveloperPocCredential.changeset(dev_poc_cred, %{"fcm_id" => fcm_id, "platform" => platform}) |> AuditedRepo.update(user_map)
    end
  end

  def update_apns_id(user_uuid, apns_id, user_map) do
    case get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        credential |> Credential.apns_changeset(apns_id) |> AuditedRepo.update(user_map)
    end
  end

  def update_app_type(user_uuid, app_type) do
    credential = get_credential_by_uuid(user_uuid)
    credential |> Credential.app_type_changeset(app_type) |> Repo.update()
  end

  def validate_gst(gstin) do
    attestr_auth_key = ApplicationHelper.get_attestr_auth_key()
    {_status_code, attestr_response} = ExternalApiHelper.validate_gst(gstin, attestr_auth_key)

    if attestr_response["valid"] do
      address = List.first(attestr_response["addresses"])

      gst_address =
        "#{address["building"]}, #{address["buildingName"]}, #{address["floor"]}, #{address["street"]}, #{address["locality"]}, #{address["district"]}, #{address["state"]}, #{address["zip"]}."

      {true,
       %{
         gst: gstin,
         gst_legal_name: attestr_response["legalName"],
         gst_pan: attestr_response["pan"],
         gst_constitution: attestr_response["constitution"],
         gst_address: gst_address
       }}
    else
      {false, %{message: attestr_response["message"]}}
    end
  end

  def validate_pan(pan) do
    attestr_auth_key = ApplicationHelper.get_attestr_auth_key()
    {_status_code, attestr_response} = ExternalApiHelper.validate_pan(pan, attestr_auth_key)

    if attestr_response["valid"] do
      {true,
       %{
         name: attestr_response["name"]
       }}
    else
      {false, %{name: nil}}
    end
  end

  def validate_upi(upi_id) do
    attestr_auth_key = ApplicationHelper.get_attestr_auth_key()

    case ExternalApiHelper.validate_upi(upi_id, attestr_auth_key) do
      {500, :timeout} -> {false, "Timeout, please try again later."}
      {_status_code, %{"valid" => true, "name" => name}} -> {true, name}
      {_status_code, %{"message" => message}} -> {false, message}
    end
  end

  def get_or_update_contact_id(%Credential{razorpay_contact_id: nil} = credential) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    {_, contact_response} = ExternalApiHelper.create_razorpay_contact_id(credential.phone_number, credential.id, auth_key)

    if not is_nil(contact_response["id"]) do
      credential
      |> Credential.changeset(%{razorpay_contact_id: contact_response["id"]})
      |> Repo.update()
    else
      ApplicationHelper.notify_on_slack("Razorpay issue for phone_number:#{credential.phone_number}: <@U02JG7END9B>, <@U03MCEL5WU8> contact_response: #{inspect(contact_response)}", ApplicationHelper.get_slack_channel())
      {:error, :razorpay}
    end
  end

  def get_or_update_contact_id(%Credential{} = credential), do: {:ok, credential}

  def update_bank_acount_into_razorpay(bank_account, credential) do
    auth_key = ApplicationHelper.get_razorpay_auth_key()

    with {:ok, %Credential{razorpay_contact_id: razorpay_contact_id}} <- BnApis.Accounts.get_or_update_contact_id(credential),
         {:fund_account, {_status_code, %{"id" => fund_id}}} <- {:fund_account, ExternalApiHelper.create_razorpay_fund_account_id(razorpay_contact_id, bank_account, auth_key)} do
      {:ok, fund_id}
    else
      {:error, :razorpay} -> {:error, "Issue with Razorpay"}
      {:fund_account, {_status_code, %{"error" => error}}} -> {:error, error["description"]}
    end
  end

  def update_upi_id(user_uuid, upi_id, user_map) do
    case get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        auth_key = ApplicationHelper.get_razorpay_auth_key()

        {razorpay_contact_id, contact_response} =
          if is_nil(credential.razorpay_contact_id) do
            {_status_code, contact_response} =
              ExternalApiHelper.create_razorpay_contact_id(
                credential.phone_number,
                credential.id,
                auth_key
              )

            {contact_response["id"], contact_response}
          else
            {credential.razorpay_contact_id, nil}
          end

        {_status_code, fund_response} =
          ExternalApiHelper.create_razorpay_fund_account_id(
            razorpay_contact_id,
            upi_id,
            auth_key
          )

        razorpay_fund_account_id = fund_response["id"]

        {upi_name_status, upi_name} = validate_upi(upi_id)

        if !is_nil(razorpay_fund_account_id) and !is_nil(razorpay_contact_id) and upi_name_status == true do
          credential |> Credential.razorpay_changeset(upi_id, upi_name, razorpay_contact_id, razorpay_fund_account_id) |> AuditedRepo.update(user_map)
        else
          channel = ApplicationHelper.get_slack_channel()

          ApplicationHelper.notify_on_slack(
            "Razorpay issue: <@U02JG7END9B>, <@U03MCEL5WU8> fund_response: #{inspect(fund_response)}, contact_response: #{inspect(contact_response)}",
            channel
          )

          {:error, "Our payment partner is facing some issues, try after 5 min."}
        end
    end
  end

  def fetch_upi_id(razorpay_contact_id, razorpay_fund_account_id) do
    upi_presence =
      !is_nil(razorpay_contact_id) &&
        !is_nil(razorpay_fund_account_id)

    if upi_presence do
      try do
        auth_key = ApplicationHelper.get_razorpay_auth_key()

        {_status_code, fund_get_response} =
          ExternalApiHelper.get_fund_account_id_details(
            razorpay_fund_account_id,
            auth_key
          )

        address = fund_get_response["vpa"]["address"]
        {upi_presence, address}
      rescue
        _ ->
          {false, nil}
      end
    else
      {false, nil}
    end
  end

  def check_upi_id(user_uuid) do
    case get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        credential =
          if credential.organization.team_upi_cred_uuid do
            get_credential_by_uuid(credential.organization.team_upi_cred_uuid)
          else
            credential
          end

        fetch_upi_id(credential.razorpay_contact_id, credential.razorpay_fund_account_id)
    end
  end

  def authenticate_chat_token(user_uuid, chat_token) do
    case get_credential_by_uuid(user_uuid) do
      nil ->
        {:error, "User not found"}

      credential ->
        is_valid = credential.chat_auth_token == chat_token
        {:ok, is_valid}
    end
  end

  alias BnApis.Accounts.WhitelistedNumber

  @doc """
  Gets a single whitelisted_number.

  Raises `Ecto.NoResultsError` if the Whitelisted number does not exist.

  ## Examples

      iex> get_whitelisted_number!(123)
      %WhitelistedNumber{}

      iex> get_whitelisted_number!(456)
      ** (Ecto.NoResultsError)

  """
  def get_whitelisted_number!(id), do: Repo.get!(WhitelistedNumber, id)

  @doc """
  Creates a whitelisted_number.

  ## Examples

      iex> create_whitelisted_number(%{field: value})
      {:ok, %WhitelistedNumber{}}

      iex> create_whitelisted_number(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_whitelisted_number(attrs \\ %{}) do
    %WhitelistedNumber{}
    |> WhitelistedNumber.changeset(attrs)
    |> Repo.insert()
  end

  def promote_user(logged_in_user, params) do
    Credential.promote_user(logged_in_user, params)
  end

  def demote_user(logged_in_user, params) do
    Credential.demote_user(logged_in_user, params)
  end

  @doc """
  Creates a employee credential.
  ## Examples
      iex> create_employee_credential(%{field: value})
      {:ok, %EmployeeCredential{}}
      iex> create_employee_credential(%{field: bad_value})
      {:error, %Ecto.Changeset{}}
  """
  def create_employee_credential(attrs, user_map) do
    %EmployeeCredential{}
    |> EmployeeCredential.changeset(attrs)
    |> AuditedRepo.insert(user_map)
  end

  def get_employee_credential_by_uuid(%EmployeeCredential{} = cred), do: cred

  def get_employee_credential_by_uuid(uuid) do
    Repo.get_by(EmployeeCredential, uuid: uuid)
  end

  def get_developer_credential_by_uuid(%DeveloperCredential{} = cred), do: cred

  def get_developer_credential_by_uuid(uuid) do
    Repo.get_by(DeveloperCredential, uuid: uuid)
  end

  def get_developer_poc_credential_by_uuid(%DeveloperPocCredential{} = cred), do: cred

  def get_developer_poc_credential_by_uuid(uuid) do
    Repo.get_by(DeveloperPocCredential, uuid: uuid)
  end

  def signup_employee_user(params = %{"phone_number" => phone_number, "country_code" => country_code}, user_map) do
    case get_active_employee_credential_by_phone(phone_number, country_code) do
      nil ->
        EmployeeCredential.signup_user(params, user_map)

      %{active: true} ->
        {:error, "You have already signed up. Try login!"}

      _ ->
        {:error, "Unknown error occured!"}
    end
  end

  def is_admin_user_present?(phone_number, country_code) do
    case get_active_employee_credential_by_phone(phone_number, country_code) do
      nil ->
        {:error, "Account not found!"}

      %{active: true} = employee_credential ->
        {:ok, employee_credential}

      %{active: false} ->
        {:error, "Account deactived!"}
    end
  end

  def is_developer_user_present?(phone_number, country_code) do
    case get_active_developer_credential_by_phone(phone_number, country_code) do
      nil ->
        {:error, "Account not found!"}

      %{active: true} = developer_credential ->
        {:ok, developer_credential}

      %{active: false} ->
        {:error, "Account deactived!"}
    end
  end

  def check_developer_poc_user_present(phone_number, country_code) do
    case get_active_developer_poc_credential_by_phone(
           phone_number,
           country_code
         ) do
      nil ->
        {:error, "Account not found!"}

      %{active: true} = developer_poc_credential ->
        {:ok, developer_poc_credential}

      %{active: false} ->
        {:error, "Account deactived!"}
    end
  end

  def update_profile(uuid, params, user_map) do
    uuid
    |> get_employee_credential_by_uuid()
    |> EmployeeCredential.update_profile_changeset(params)
    |> AuditedRepo.update(user_map)
  end

  def update_profile_pic(uuid, params, user_map) do
    uuid
    |> get_employee_credential_by_uuid()
    |> EmployeeCredential.update_profile_pic_changeset(params)
    |> AuditedRepo.update(user_map)
  end

  @doc """
  For all Brokers ->
    Find latest_outstanding_match date
    Find latest_property_post date
    Find latest_client_post date
    Find latest_match date
    Uninstall
  """
  def brokers_dashboard_details(_logged_in_user, page, broker_ids) do
    Credential.employee_dashboard_credentials_query(page, broker_ids)
    |> Repo.all()
    |> Enum.map(fn broker_details ->
      profile_image =
        case broker_details.profile_image do
          nil -> nil
          %{"url" => nil} -> nil
          %{"url" => url} -> S3Helper.get_imgix_url(url)
        end

      broker_cred_id = broker_details.id

      latest_outstanding_match_date = Posts.fetch_latest_outstanding_match_date(broker_cred_id)

      latest_match_date = Posts.fetch_latest_match_date(broker_cred_id)

      latest_property_post_date = Posts.fetch_latest_property_post_query(broker_cred_id)

      latest_client_post_date = Posts.fetch_latest_client_post_query(broker_cred_id)

      list =
        [latest_client_post_date, latest_property_post_date]
        |> Enum.reject(&is_nil/1)

      latest_post_date =
        case list |> length do
          0 -> nil
          _ -> list |> Enum.max()
        end

      %{
        uuid: broker_details.uuid,
        phone_number: broker_details.phone_number,
        last_activity: broker_details.last_active_at |> Time.naive_to_epoch(),
        uninstalled: uninstalled?(broker_details),
        name: broker_details.name,
        org_name: broker_details.org_name,
        profile_pic_url: profile_image,
        latest_post_date: latest_post_date && latest_post_date * 1000,
        latest_match_date: latest_match_date && latest_match_date * 1000,
        # color_code_id
        outstanding_matches_status: color_code_id(latest_outstanding_match_date),
        # color_code_id
        property_post_status: color_code_id(latest_property_post_date),
        # color_code_id
        client_post_status: color_code_id(latest_client_post_date),
        # color_code_id
        matches_status: color_code_id(latest_match_date)
      }
    end)
    |> Enum.sort_by(& &1.matches_status, &>=/2)
  end

  # 1. installed flag should be false along with nil fcm_id
  # 2. last uninstall notification is atleast a day old
  def uninstalled?(user_details) do
    !user_details.installed &&
      is_nil(user_details.fcm_id) &&
      is_valid_uninstall(user_details.id)
  end

  # 1. Last uninstall notif should be atleast a day old
  def is_valid_uninstall(user_id) do
    case user_id |> Request.get_latest_notif("UNINSTALL", "not_registered") do
      nil ->
        false

      notif ->
        notif.inserted_at |> NaiveDateTime.diff(NaiveDateTime.utc_now()) <=
          -@day_seconds
    end
  end

  def color_code_id(date) when is_nil(date), do: ColorCode.red().id

  def color_code_id(date) do
    date = round(date * 1000) |> Time.epoch_to_naive()
    now = NaiveDateTime.utc_now()
    days = (NaiveDateTime.diff(now, date, :second) / (60 * 60 * 24)) |> round

    cond do
      days == 0 or days == 1 -> ColorCode.green().id
      days == 2 -> ColorCode.yellow().id
      days >= 3 -> ColorCode.red().id
      true -> ColorCode.red().id
    end
  end

  def get_broker!(id), do: Repo.get!(Broker, id)
  def get_broker(id), do: Repo.get(Broker, id)

  ## first check if credential exists
  @doc """
    1. First check if credential exists with phone
      a. If it exits check if broker id and organization id exists
      b. If either of them does not exist create and associate
    2. If credential not exists then create broker , organization and associate with new credential
  """
  def create_account_info(params = %{"phone_number" => phone_number, "country_code" => country_code}, user_map) do
    credential = Credential |> where([c], c.phone_number == ^phone_number and c.country_code == ^country_code) |> Repo.all()

    exists = credential |> length > 0

    case exists do
      false ->
        {:ok, %Organization{} = organization} = get_or_create_organization(params)

        # create new broker here since broker is unique with orgnaization
        case Broker.create_broker(params, user_map) do
          {:ok, broker} ->
            params
            |> Map.merge(%{
              "organization_id" => organization.id,
              "broker_id" => broker.id
            })
            |> Credential.create_or_get_credential(user_map)

          {:error, changeset} ->
            {:error, changeset}
        end

      true ->
        {:error, "Number already exists."}
    end
  end

  # Private function
  defp get_active_developer_poc_credential_by_phone(phone_number, country_code) do
    Repo.get_by(DeveloperPocCredential, phone_number: phone_number, country_code: country_code, active: true)
  end

  defp get_active_employee_credential_by_phone(phone_number, country_code) do
    Repo.get_by(EmployeeCredential, phone_number: phone_number, country_code: country_code, active: true)
  end

  defp get_active_developer_credential_by_phone(phone_number, country_code) do
    Repo.get_by(DeveloperCredential, phone_number: phone_number, country_code: country_code, active: true)
  end

  defp get_or_create_organization(%{"organization_uuid" => value}) when not is_nil(value) do
    org = Organization.get_organization_by_uuid(value)
    if org, do: {:ok, org}, else: {:error, nil}
  end

  defp get_or_create_organization(params),
    do: Organization.create_organization(params)
end
