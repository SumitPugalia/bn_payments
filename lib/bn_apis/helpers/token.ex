defmodule BnApis.Helpers.Token do
  use Appsignal.Instrumentation.Decorators

  alias BnApis.Accounts
  alias BnApis.Packages
  alias BnApis.Repo
  alias BnApis.Accounts.ProfileType
  alias BnApis.Places.Locality
  alias BnApis.Places.Polygon
  alias BnApis.Helpers.{Redis, S3Helper, Otp, ApplicationHelper}
  alias BnApis.Developers.DeveloperCredentialProject
  alias BnApis.FeedTransactions.FeedTransactionLocality
  alias BnApis.Memberships.MatchPlusMembership
  alias BnApis.Orders.MatchPlus
  alias BnApis.Stories.StoryDeveloperPocMapping
  alias BnApis.Organizations.{BillingCompany, Broker}
  alias BnApis.Accounts.Credential
  alias BnApis.Schemas.LegalEntityPoc
  alias BnApis.Accounts.EmployeeRole
  alias BnApis.Organizations.Organization
  # alias BnApis.Rewards

  @broker_profile_type_id ProfileType.broker().id
  @employee_profile_type_id ProfileType.employee().id
  @developer_profile_type_id ProfileType.developer().id
  @developer_poc_profile_type_id ProfileType.developer_poc().id
  @legal_entity_poc_admin ProfileType.legal_entity_poc_admin().id
  @legal_entity_poc ProfileType.legal_entity_poc().id

  # SESSION TOKEN
  @token_prefix %{
    @broker_profile_type_id => "ST_",
    @employee_profile_type_id => "EMP_ST_",
    @developer_profile_type_id => "DEV_ST_",
    @developer_poc_profile_type_id => "DEV_POC_ST_",
    @legal_entity_poc_admin => "LEA_POC_ST_",
    @legal_entity_poc => "LE_POC_ST_"
  }
  # SESSION TOKEN MAP
  @token_map_prefix %{
    @broker_profile_type_id => "STM_",
    @employee_profile_type_id => "EMP_STM_",
    @developer_profile_type_id => "DEV_STM_",
    @developer_poc_profile_type_id => "DEV_POC_STM_",
    @legal_entity_poc_admin => "LEA_POC_STM_",
    @legal_entity_poc => "LE_POC_STM_"
  }

  # 1 Month long sessions by default
  @expires_in 3600 * 24 * 30
  @imgix_domain ApplicationHelper.get_imgix_domain()

  defp get_default_locality() do
    # Default Locality
    locality = Repo.get_by(Locality, name: "Powai")
    polygon = Repo.get_by(Polygon, name: "Powai")

    unless is_nil(locality) do
      # ranges = Transaction.get_ranges_for_transactions(locality.id)
      %{
        "id" => polygon.id,
        "name" => polygon.name,
        "uuid" => polygon.uuid,
        "polygon_uuid" => polygon.uuid,
        "min_rent" => 0,
        "min_price" => 0,
        "min_area" => "",
        "max_rent" => 0,
        "max_price" => 0,
        "max_area" => "",
        "count" => 0
      }
    end
  end

  def create_token_data(credential_uuid, profile_type_id, is_match_plus_dynamic)
      when profile_type_id == @broker_profile_type_id do
    credential = Accounts.get_credential_by_uuid(credential_uuid)
    broker = credential.broker

    match_plus = MatchPlus.get_data_by_broker(broker)
    user_package = Packages.get_data_by_broker(broker)

    match_plus =
      if is_match_plus_dynamic != true do
        MatchPlus.get_latest_match_plus(match_plus, user_package)
      else
        match_plus_membership = MatchPlusMembership.get_data_by_broker(broker)
        ApplicationHelper.format_match_plus(match_plus, match_plus_membership, user_package, broker.operating_city)
      end

    qr_code_url = broker.qr_code_url
    qr_code_url = if !is_nil(qr_code_url), do: S3Helper.get_imgix_url(qr_code_url)

    # Rewards.draft_leads_count(broker.id)
    draft_sv_count = 0

    upi_id =
      if credential.organization.team_upi_cred_uuid do
        cred = Credential.get_by_uuid_query(credential.organization.team_upi_cred_uuid) |> Repo.one()
        cred.upi_id
      else
        credential.upi_id
      end

    member_count =
      Organization.active_team_members_query(credential.organization_id)
      |> Repo.aggregate(:count, :id)

    %{
      "user_id" => credential.id,
      "uuid" => credential.uuid,
      "active" => credential.active,
      "profile" => %{
        "payment_from_org_upi" => not is_nil(credential.organization.team_upi_cred_uuid),
        "chat_app_id" => ApplicationHelper.get_sendbird_application_id(),
        "chat_api_token" => ApplicationHelper.get_sendbird_api_token(),
        "id" => credential.uuid,
        "broker_id" => broker.id,
        "phone_number" => credential.phone_number,
        "country_code" => credential.country_code,
        "can_leave" => member_count > 1,
        "name" => broker.name,
        "profile_pic_url" => get_image_url(broker.profile_image),
        "organization_id" => credential.organization_id,
        "organization_name" => credential.organization.name,
        "firm_address" => credential.organization.firm_address,
        "gst_number" => credential.organization.gst_number,
        "rera_id" => credential.organization.rera_id,
        "broker_role_id" => credential.broker_role_id,
        "qr_code_url" => qr_code_url,
        "chat_auth_token" => credential.chat_auth_token,
        "fcm_id" => credential.fcm_id,
        "test_user" => credential.test_user,
        "operating_city" => broker.operating_city,
        "locality" => get_locality_details(broker.polygon),
        "default_transaction_locality" => get_default_feed_locality(broker.polygon),
        "city_id" => broker.operating_city,
        "is_match_enabled" => broker.is_match_enabled,
        "is_cab_booking_enabled" => broker.is_cab_booking_enabled,
        "is_invoicing_enabled" => broker.is_match_enabled,
        "is_location_mandatory_for_rewards" => broker.is_location_mandatory_for_rewards,
        "match_plus" => match_plus,
        "pan" => broker.pan,
        "pan_url" => get_image_url(broker.pan_image),
        "rera" => broker.rera,
        "rera_file" => get_image_url(broker.rera_file),
        "draft_sv_count" => draft_sv_count,
        "portrait_kit_url" => broker.portrait_kit_url,
        "landscape_kit_url" => broker.landscape_kit_url,
        "broker_type_id" => broker.role_type_id,
        "hl_tnc_agreed" => broker.homeloans_tnc_agreed,
        "kyc" => Broker.fetch_broker_kyc_details(broker) |> Map.put("upi_id", upi_id),
        "failed_billing_companies_count" => BillingCompany.get_change_requested_billing_company_count(broker.id),
        "is_employee" => broker.is_employee,
        "employee_details" => if(broker.is_employee, do: Credential.get_employee_details_using_broker_id(broker.id), else: %{})
      }
    }
  end

  def create_token_data(employee_credential_uuid, profile_type_id, _is_match_plus_dynamic)
      when profile_type_id == @employee_profile_type_id do
    employee_credential = Accounts.get_employee_credential_by_uuid(employee_credential_uuid) |> Repo.preload([:vertical])
    employee_role = EmployeeRole.get_by_id(employee_credential.employee_role_id)
    employee_role_name = if not is_nil(employee_role), do: employee_role.name, else: nil

    %{
      "user_id" => employee_credential.id,
      "uuid" => employee_credential.uuid,
      "operational_cities" => ApplicationHelper.get_operational_cities(),
      "profile" => %{
        "chat_app_id" => ApplicationHelper.get_sendbird_application_id(),
        "chat_api_token" => ApplicationHelper.get_sendbird_api_token(),
        "id" => employee_credential.uuid,
        "employee_id" => employee_credential.id,
        "vertical_id" => employee_credential.vertical_id,
        "vertical_name" => employee_credential.vertical.name,
        "phone_number" => employee_credential.phone_number,
        "country_code" => employee_credential.country_code,
        "name" => employee_credential.name,
        "profile_pic_url" => get_image_url(employee_credential.profile_image_url),
        "organization_name" => "Broker Network",
        "employee_role_id" => employee_credential.employee_role_id,
        "employee_role_name" => employee_role_name,
        "skip_allowed" => employee_credential.skip_allowed,
        "city_id" => employee_credential.city_id
      }
    }
  end

  def create_token_data(developer_credential_uuid, profile_type_id, _is_match_plus_dynamic)
      when profile_type_id == @developer_profile_type_id do
    developer_credential = Accounts.get_developer_credential_by_uuid(developer_credential_uuid)

    projects = developer_credential.id |> DeveloperCredentialProject.get_active_projects()

    %{
      "user_id" => developer_credential.id,
      "uuid" => developer_credential.uuid,
      "profile" => %{
        "chat_app_id" => ApplicationHelper.get_sendbird_application_id(),
        "chat_api_token" => ApplicationHelper.get_sendbird_api_token(),
        "id" => developer_credential.uuid,
        "phone_number" => developer_credential.phone_number,
        "name" => developer_credential.name,
        "profile_pic_url" => get_image_url(developer_credential.profile_image_url),
        "projects" => projects
      }
    }
  end

  def create_token_data(developer_poc_credential_uuid, profile_type_id, _is_match_plus_dynamic)
      when profile_type_id == @developer_poc_profile_type_id do
    poc_credential = Accounts.get_developer_poc_credential_by_uuid(developer_poc_credential_uuid)
    story_mapping = StoryDeveloperPocMapping.get_story_map_from_poc_credential_id(poc_credential.id)

    {story_uuid, story_name, project_logo_url} =
      if not is_nil(story_mapping),
        do: {story_mapping.story.uuid, story_mapping.story.name, story_mapping.story.project_logo_url},
        else: {nil, nil, nil}

    %{
      "user_id" => poc_credential.id,
      "uuid" => poc_credential.uuid,
      "story_uuid" => story_uuid,
      "story_name" => story_name,
      "project_logo_url" => project_logo_url,
      "profile" => %{
        "chat_app_id" => ApplicationHelper.get_sendbird_application_id(),
        "chat_api_token" => ApplicationHelper.get_sendbird_api_token(),
        "id" => poc_credential.uuid,
        "phone_number" => poc_credential.phone_number,
        "name" => poc_credential.name
      }
    }
  end

  def create_token_data(poc_credential_uuid, profile_type_id, _is_match_plus_dynamic)
      when profile_type_id in [@legal_entity_poc_admin, @legal_entity_poc] do
    poc_credential = if is_struct(poc_credential_uuid), do: poc_credential_uuid, else: LegalEntityPoc.get_by_uuid(poc_credential_uuid)

    %{
      "user_id" => poc_credential.id,
      "uuid" => poc_credential.uuid,
      "profile" => %{
        "id" => poc_credential.id,
        "phone_number" => poc_credential.phone_number,
        "name" => poc_credential.poc_name,
        "profile_type_id" => profile_type_id,
        "role_type" => poc_credential.poc_type
      }
    }
  end

  def initialize_broker_token(credential_uuid) do
    credential = Accounts.get_credential_by_uuid(credential_uuid)
    # Clean OTP request count
    Otp.clean_otp_request_count(credential.phone_number, @broker_profile_type_id)

    token_data = create_token_data(credential.uuid, @broker_profile_type_id, false)
    initialize_token(token_data, @broker_profile_type_id)
  end

  def initialize_legal_entity_token(legal_entity_poc, profile_type_id) do
    # Clean OTP request count
    Otp.clean_otp_request_count(legal_entity_poc.phone_number, profile_type_id)

    token_data = create_token_data(legal_entity_poc, profile_type_id, false)
    initialize_token(token_data, profile_type_id)
  end

  @doc """
  1 Hour session timeout for Employees
  Creates session data for employees
  """
  def initialize_employee_token(employee_credential_uuid, _expires_in \\ 3600) do
    # _employee_credential = Accounts.get_employee_credential_by_uuid(employee_credential_uuid)
    # Clean OTP request count
    # Otp.clean_otp_request_count(employee_credential.phone_number, @employee_profile_type_id)
    token_data = create_token_data(employee_credential_uuid, @employee_profile_type_id, false)
    initialize_token(token_data, @employee_profile_type_id)
  end

  def initialize_developer_token(developer_credential_uuid, _expires_in \\ 3600) do
    # _developer_credential = Accounts.get_developer_credential_by_uuid(developer_credential_uuid)
    token_data = create_token_data(developer_credential_uuid, @developer_profile_type_id, false)
    initialize_token(token_data, @developer_profile_type_id)
  end

  def initialize_developer_poc_token(developer_poc_credential_uuid) do
    token_data = create_token_data(developer_poc_credential_uuid, @developer_poc_profile_type_id, false)
    initialize_token(token_data, @developer_poc_profile_type_id, 3600 * 10)
  end

  def initialize_token(token_data, profile_type_id, expires_in \\ @expires_in) do
    user_id = "#{token_data[:user_id] || token_data["user_id"]}"
    token = get_token(user_id, profile_type_id)
    token_prefix = @token_prefix[profile_type_id]
    # Redis.q(["hset", token_prefix <> token, "data", token_data |> Poison.encode!])
    Redis.q(["hset", token_prefix <> token, "user_uuid", token_data["uuid"]])
    Redis.q(["hset", token_prefix <> token, "expires_in", expires_in])
    Redis.q(["hset", token_prefix <> token, "user_id", user_id])
    Redis.q(["sadd", @token_map_prefix[profile_type_id] <> user_id, token])
    Redis.q(["expire", token_prefix <> token, expires_in])
    {:ok, token}
  end

  def get_token_data(token, profile_type_id \\ @broker_profile_type_id, is_match_plus_dynamic \\ false) do
    case Redis.q(["hget", @token_prefix[profile_type_id] <> token, "user_uuid"]) do
      {:ok, nil} ->
        %{}

      {:ok, user_uuid} ->
        extend_token(token, profile_type_id)
        token_data = create_token_data(user_uuid, profile_type_id, is_match_plus_dynamic)
        token_data
    end
  end

  def extend_token(token, profile_type_id) do
    case Redis.q(["hget", @token_prefix[profile_type_id] <> token, "expires_in"]) do
      {:ok, expires_in} ->
        extend_token(token, profile_type_id, expires_in)

      _ ->
        nil
    end
  end

  def extend_token(token, profile_type_id, expires_in) do
    Redis.q(["expire", @token_prefix[profile_type_id] <> token, expires_in])
  end

  def destroy_token(token, profile_type_id) do
    case Redis.q(["hget", @token_prefix[profile_type_id] <> token, "user_id"]) do
      {:ok, nil} ->
        IO.inspect("nil user_id")

      {:ok, user_id} ->
        Redis.q(["del", @token_prefix[profile_type_id] <> token])
        Redis.q(["srem", @token_map_prefix[profile_type_id] <> user_id, token])
    end
  end

  @decorate transaction_event()
  def destroy_all_user_tokens(user_id, profile_type_id) do
    {:ok, tokens} = Redis.q(["smembers", @token_map_prefix[profile_type_id] <> "#{user_id}"])

    tokens
    |> Enum.each(fn token ->
      destroy_token(token, profile_type_id)
    end)

    Redis.q(["del", @token_map_prefix[profile_type_id] <> "#{user_id}"])
  end

  # defp redis_array_to_map([]), do: %{}
  # defp redis_array_to_map([key]), do: %{key => nil}
  # defp redis_array_to_map([key|[value|array]]) do
  #   Map.merge(%{key => value}, redis_array_to_map(array))
  # end

  defp get_token(user_id, profile_type_id) do
    token = SecureRandom.urlsafe_base64(128)

    case Redis.q(["hsetnx", @token_prefix[profile_type_id] <> token, "user_id", user_id]) do
      {:ok, 1} ->
        token

      {:ok, 0} ->
        get_token(user_id, profile_type_id)
    end
  end

  defp get_image_url(nil), do: nil
  defp get_image_url(%{"url" => nil}), do: nil

  defp get_image_url(%{"url" => url}) do
    String.contains?(url, @imgix_domain)
    |> case do
      true -> url
      false -> S3Helper.get_imgix_url(url)
    end
  end

  defp get_default_feed_locality(nil), do: %{}
  defp get_default_feed_locality(%Polygon{uuid: uuid}), do: FeedTransactionLocality.get_default_feed_locality(uuid)

  defp get_locality_details(nil), do: get_default_locality()

  defp get_locality_details(%Polygon{uuid: uuid, id: id, name: name}),
    do: %{
      "id" => id,
      "name" => name,
      "uuid" => uuid,
      "polygon_uuid" => uuid,
      "min_rent" => 0,
      "min_price" => 0,
      "min_area" => "",
      "max_rent" => 0,
      "max_price" => 0,
      "max_area" => "",
      "count" => 0
    }
end
