defmodule BnApis.Organizations.Broker do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts
  alias BnApis.Accounts.{Credential, EmployeeCredential, EmployeeRole}
  alias BnApis.Accounts.WhitelistedNumber
  alias BnApis.Accounts.WhitelistedBrokerInfo
  alias BnApis.Helpers.Otp
  alias BnApis.Helpers.AssignedBrokerHelper
  alias BnApis.Places.Polygon
  alias BnApisWeb.Helpers.PhoneHelper, as: Phone
  alias BnApis.Organizations.{Broker, Organization, BrokerType, BillingCompany, ValidRera, BrokerRole, OrgJoiningRequests}
  alias BnApis.Helpers.{FormHelper, S3Helper, Time, ApplicationHelper, AuditedRepo, Utils}
  alias BnApis.Orders.MatchPlus
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Organizations.BrokerCommission
  alias BnApis.Accounts.ProfileType
  alias BnApis.Helpers.Token
  alias BnApis.Signzy.API
  alias BnApis.Accounts.Invite
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.EmployeeVertical
  alias BnApis.Rewards.Status

  @fallback_profile_image %{url: "profile_avatar.png"}
  @imgix_domain ApplicationHelper.get_imgix_domain()
  @pending_request_message "You have a pending organization joining request, please get it approved before you can fill in KYC details."
  @project_vertical_id EmployeeVertical.get_vertical_by_identifier("PROJECT")["id"]

  schema "brokers" do
    field(:name, :string)
    field(:profile_image, :map)
    field(:qr_code_url, :string)
    field(:operating_city, :integer)
    field(:level_id, :integer)
    field(:is_match_enabled, :boolean, default: true)
    field(:is_cab_booking_enabled, :boolean, default: false)
    field(:is_invoicing_enabled, :boolean, default: false)
    field(:is_location_mandatory_for_rewards, :boolean, default: false)
    field(:pan, :string)
    field(:pan_image, :map)
    field(:pan_name, :string)
    field(:rera, :string)
    field(:rera_file, :map)
    field(:rera_name, :string)
    field(:portrait_kit_url, :string)
    field(:landscape_kit_url, :string)
    field(:shortlisted_rental_posts, {:array, :map}, default: [])
    field(:shortlisted_resale_posts, {:array, :map}, default: [])
    field(:shortlisted_commercial_property_posts, {:array, :map}, default: [])
    field(:max_rewards_per_day, :integer)
    field(:email, :string)
    # 1 for real estate broker and 2 for dsa
    field(:role_type_id, :integer)
    field(:homeloans_tnc_agreed, :boolean, default: false)
    # after whitelisting dsa has to be approved from panel
    field(:hl_commission_status, :integer)
    field(:hl_commission_rej_reason, :string)

    field(:kyc_status, Ecto.Enum, values: [:missing, :approval_pending, :approved, :rejected], default: :missing)
    field(:change_notes, :string)
    field(:is_pan_verified, :boolean, default: false)
    field(:is_rera_verified, :boolean, default: false)
    field(:is_employee, :boolean, default: false)

    has_one(:broker_commission, BrokerCommission,
      foreign_key: :broker_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    belongs_to(:polygon, Polygon)
    belongs_to(:broker_type, BrokerType)

    has_many(:credentials, Credential, foreign_key: :broker_id)

    has_many(:billing_companies, BillingCompany,
      foreign_key: :broker_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  @fields [
    :name,
    :profile_image,
    :qr_code_url,
    :operating_city,
    :broker_type_id,
    :polygon_id,
    :is_match_enabled,
    :is_cab_booking_enabled,
    :is_invoicing_enabled,
    :is_location_mandatory_for_rewards,
    :pan,
    :pan_image,
    :rera,
    :rera_file,
    :rera_name,
    :shortlisted_rental_posts,
    :shortlisted_resale_posts,
    :shortlisted_commercial_property_posts,
    :portrait_kit_url,
    :landscape_kit_url,
    :max_rewards_per_day,
    :level_id,
    :email,
    :role_type_id,
    :homeloans_tnc_agreed,
    :hl_commission_status,
    :hl_commission_rej_reason,
    :kyc_status,
    :change_notes,
    :is_pan_verified,
    :is_rera_verified,
    :is_employee,
    :pan_name
  ]
  @required_fields [:name]

  @valid_cities_in_maharastra [1, 2]
  @broker_schema_name "brokers"

  @invalid_pan_error_message "Invalid PAN details"
  @invalid_rera_error_message "Invalid RERA details"

  @valid_status_change %{
    nil => [:missing, :approval_pending],
    :missing => [:approval_pending, :approved, :rejected],
    :approval_pending => [:approved, :rejected, :missing],
    :approved => [:missing, :rejected, :approval_pending],
    :rejected => [:approval_pending, :missing, :approved]
  }

  def broker_schema_name() do
    @broker_schema_name
  end

  # role_type_id
  @real_estate_broker %{
    "id" => 1,
    "name" => "Real Estate Broker",
    "identifier" => "real_estate_broker"
  }

  @dsa %{
    "id" => 2,
    "name" => "DSA",
    "identifier" => "dsa"
  }

  def dsa do
    @dsa
  end

  def real_estate_broker do
    @real_estate_broker
  end

  def list_broker_types do
    [
      @dsa,
      @real_estate_broker
    ]
  end

  @pending %{
    "id" => 1,
    "name" => "pending",
    "display_name" => "Pending"
  }
  @approved %{
    "id" => 2,
    "name" => "approved",
    "display_name" => "Approved"
  }
  @rejected %{
    "id" => 3,
    "name" => "rejected",
    "display_name" => "Rejected"
  }

  def pending do
    @pending
  end

  def approved do
    @approved
  end

  def rejected do
    @rejected
  end

  def list_status_type do
    [
      @pending,
      @approved,
      @rejected
    ]
  end

  def get_status_id(status) do
    [status] = [pending(), approved(), rejected()] |> Enum.filter(fn s -> s["name"] == status end)
    status["id"]
  end

  def get_broker_status_list() do
    [@pending, @approved, @rejected]
  end

  @doc false
  def changeset(broker, attrs \\ %{}) do
    old_status = Map.get(broker, :kyc_status)

    broker
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_if_pan_already_exist()
    |> restrict_kyc_details_change()
    |> validate_attachment([:profile_image],
      allowed_extensions: ["jpg", "jpeg", "png"]
    )
    |> validate_kyc_state_change(old_status)
    |> foreign_key_constraint(:polygon_id)
    |> unique_constraint(:pan, name: :unique_pan_on_brokers, message: "PAN already in use.")
  end

  def all_brokers() do
    Broker
    |> Repo.all()
  end

  def update(broker, attrs, user_map) do
    broker
    |> Broker.changeset(attrs)
    |> AuditedRepo.update(user_map)
  end

  def update_pan(broker, attrs, user_map) do
    broker
    |> cast(attrs, [:pan])
    |> AuditedRepo.update(user_map)
  end

  def all_active_brokers(params) do
    page = (params["p"] && params["p"] |> String.to_integer()) || 1
    size = 100

    query =
      Broker
      |> join(:inner, [b], c in Credential, on: c.broker_id == b.id)
      |> where([b, c], c.active == true)

    brokers =
      query
      |> order_by([b, c], desc: b.inserted_at)
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> Repo.all()

    total_count = query |> Repo.aggregate(:count, :id)
    has_more_brokers = page < Float.ceil(total_count / size)
    {brokers, has_more_brokers}
  end

  def index(params, employee_role_id, user_id) do
    page = (params["p"] && params["p"]) || 1
    active = if is_nil(params["inactive"]), do: true, else: false
    kyc_status = Map.get(params, "kyc_status") |> parse_string() |> parse_kyc_state()
    size = 100

    query =
      Broker
      |> join(:inner, [b], c in Credential, on: c.broker_id == b.id)
      |> join(:left, [b, c], o in Organization, on: c.organization_id == o.id)
      |> join(:left, [b, c, o], p in Polygon, on: p.id == b.polygon_id)
      |> join(:left, [b, c, o, p], m in MatchPlus, on: m.broker_id == b.id)
      |> where([b, c, o, p, m], c.active == ^active)
      |> filter_by_kyc_status(kyc_status)

    query =
      if !is_nil(params["q"]) && is_binary(params["q"]) && String.trim(params["q"]) != "" do
        q = params["q"]
        name_query = "%#{String.downcase(String.trim(q))}%"

        query
        |> where(
          [b, c, o, p],
          c.phone_number == ^q or fragment("LOWER(?) LIKE ?", b.name, ^name_query) or
            fragment("LOWER(?) LIKE ?", o.name, ^name_query)
        )
      else
        query
      end

    query =
      if not is_nil(params["min_created_at"]) and not is_nil(params["max_created_at"]) do
        min_created_at = params["min_created_at"] |> Time.epoch_to_naive()
        max_created_at = params["max_created_at"] |> Time.epoch_to_naive()
        query |> where([b, c, o, p], b.inserted_at >= ^min_created_at and b.inserted_at <= ^max_created_at)
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) do
        query |> where([b, c, o, p], b.operating_city == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["is_cab_booking_enabled"]) do
        is_cab_booking_enabled = params["is_cab_booking_enabled"] == "true"
        query |> where([b, c, o, p], b.is_cab_booking_enabled == ^is_cab_booking_enabled)
      else
        query
      end

    query =
      if not is_nil(params["is_match_plus_active"]) do
        status_id = if params["is_match_plus_active"] == "true", do: 1, else: 2
        query |> where([b, c, o, p, m], m.status_id == ^status_id)
      else
        query
      end

    query =
      if params["installed"] == "false" do
        query |> where([b, c, o, p], c.installed != true)
      else
        query
      end

    query =
      if not is_nil(params["polygon_ids"]) do
        query |> where([b, c, o, p], p.id in ^params["polygon_ids"])
      else
        query
      end

    query =
      if params["no_activity"] == "true" do
        today = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata") |> Timex.beginning_of_day()
        four_days_ago = today |> Timex.shift(days: -3) |> Timex.to_naive_datetime()
        query |> where([b, c, o, p], c.last_active_at < ^four_days_ago)
      else
        query
      end

    query =
      if not is_nil(params["role_type_id"]) and params["role_type_id"] == dsa()["id"] do
        query =
          if(employee_role_id == EmployeeRole.super().id) do
            query |> where([b, c, o, p], b.role_type_id == ^params["role_type_id"])
          else
            assigned_employees_ids = EmployeeCredential.get_all_assigned_employee_for_an_employee(user_id)

            query
            |> join(:inner, [b, c], ab in AssignedBrokers, on: ab.broker_id == b.id and ab.active == true)
            |> where([b, ..., ab], ab.employees_credentials_id in ^assigned_employees_ids)
          end

        if not is_nil(params["hl_commission_status"]) and Enum.member?([pending()["id"], approved()["id"], rejected()["id"]], params["hl_commission_status"]) do
          query |> where([b, c, o, p], b.hl_commission_status == ^params["hl_commission_status"])
        else
          query
        end
      else
        role_type_id = real_estate_broker()["id"]
        query |> where([b, c, o, p], b.role_type_id == ^role_type_id or is_nil(b.role_type_id))
      end

    brokers =
      query
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> order_by([b, c, o], desc: b.updated_at, asc: o.name, asc: b.name)
      |> select([b, c, o, p, m], %{
        active: c.active,
        phone_number: c.phone_number,
        app_version: c.app_version,
        manufacturer: c.device_manufacturer,
        model: c.device_model,
        os_version: c.device_os_version,
        last_active_at: c.last_active_at,
        id: b.id,
        name: b.name,
        polygon_id: b.polygon_id,
        polygon_name: p.name,
        app_installed: c.installed,
        profile_image: b.profile_image,
        operating_city: b.operating_city,
        broker_type_id: b.broker_type_id,
        is_cab_booking_enabled: b.is_cab_booking_enabled,
        is_match_enabled: b.is_match_enabled,
        is_match_plus_active: m.status_id == 1,
        is_pan_verified: b.is_pan_verified,
        is_rera_verified: b.is_rera_verified,
        inserted_at: b.inserted_at,
        organization_id: o.id,
        organization_uuid: o.uuid,
        organization_name: o.name,
        max_rewards_per_day: b.max_rewards_per_day,
        rera: b.rera,
        rera_name: b.rera_name,
        rera_file: b.rera_file,
        uuid: c.uuid,
        role_type_id: b.role_type_id,
        homeloans_tnc_agreed: b.homeloans_tnc_agreed,
        hl_commission_status: b.hl_commission_status,
        hl_commission_rej_reason: b.hl_commission_rej_reason,
        pan: b.pan,
        pan_image: b.pan_image,
        kyc_status: b.kyc_status,
        change_notes: b.change_notes
      })
      |> Repo.all()
      |> Enum.map(fn b ->
        broker_commission_details = get_broker_commission_details(b.id, b.role_type_id)
        assigned_emp_details = get_assigned_emp_details(b.id)
        phone_number = encrypt_broker_phone_number(b.phone_number, params["role_type_id"])
        Map.merge(b, %{broker_commission_details: broker_commission_details, assigned_emp_details: assigned_emp_details, phone_number: phone_number})
      end)

    total_count = query |> Repo.aggregate(:count, :id)
    has_more_brokers = page < Float.ceil(total_count / size)
    {brokers, has_more_brokers, total_count}
  end

  def encrypt_broker_phone_number(phone_number, role_type_id) do
    if(role_type_id == dsa()["id"]) do
      "XXXXXX" <> String.slice(phone_number, -4..-1)
    else
      phone_number
    end
  end

  def get_assigned_emp_details(broker_id) do
    AssignedBrokers
    |> join(:inner, [a], e in EmployeeCredential, on: a.employees_credentials_id == e.id and a.active == true and e.active)
    |> where([a, e], a.broker_id == ^broker_id)
    |> select([a, e], %{
      employee_id: e.id,
      employee_name: e.name,
      employee_phone_number: e.phone_number,
      employee_vertical_id: e.vertical_id
    })
    |> Repo.all()
  end

  def get_broker_commission_details(_broker_id, role_type_id) when role_type_id in [nil, 1, "1"], do: nil

  def get_broker_commission_details(broker_id, _role_type_id) do
    BrokerCommission.get_broker_commission_detail(broker_id)
  end

  def fetch_broker_from_id(id) do
    Broker |> Repo.get(id)
  end

  def fetch_broker_from_ids(ids) do
    Repo.all(from b in Broker, where: b.id in ^ids) |> Repo.preload(polygon: [:locality])
  end

  @doc """
  1. Create a new record with the given params if it does not exist
  2. Get in case record exists
  """
  def create_or_get_broker(params, user_map) do
    params = %{
      "name" => params["broker_name"],
      "profile_image" => params["profile_image"] || @fallback_profile_image
    }

    case fetch_broker(params["name"]) do
      nil ->
        %Broker{}
        |> Broker.changeset(params)
        |> AuditedRepo.insert(user_map)

      broker ->
        {:ok, broker}
    end
  end

  def maybe_update_role_type_id_using_user_role(nil, emp_user_id) do
    employee = EmployeeCredential.fetch_employee_by_id(emp_user_id)

    cond do
      employee == nil ->
        nil

      employee.employee_role_id in [EmployeeRole.dsa_agent().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_super().id] ->
        dsa()["id"]

      true ->
        real_estate_broker()["id"]
    end
  end

  def maybe_update_role_type_id_using_user_role(role_type_id, _), do: role_type_id

  def create_broker(params, user_map) do
    role_type_id = maybe_update_role_type_id_using_user_role(params["role_type_id"], user_map.user_id)

    params = %{
      "name" => params["broker_name"],
      "profile_image" => params["profile_image"] || @fallback_profile_image,
      "polygon_id" => params["polygon_id"],
      "operating_city" => params["operating_city"],
      "is_match_enabled" => params["is_match_enabled"],
      "is_cab_booking_enabled" => params["is_cab_booking_enabled"],
      "is_invoicing_enabled" => params["is_invoicing_enabled"],
      "is_location_mandatory_for_rewards" => params["is_location_mandatory_for_rewards"],
      "rera" => params["rera"],
      "rera_name" => params["rera_name"],
      "rera_file" => params["rera_file"],
      "email" => params["email"],
      "role_type_id" => role_type_id || 1,
      "hl_commission_status" => pending()["id"],
      "pan" => params["pan"]
    }

    %Broker{}
    |> Broker.changeset(params)
    |> AuditedRepo.insert(user_map)
  end

  def whitelist_broker(params, assigned_by_id, user_map, from_script?) do
    params =
      params["polygon_uuid"]
      |> Polygon.fetch_from_uuid()
      |> whitelist_broker_params(params, assigned_by_id, from_script?)

    Repo.transaction(fn ->
      with {:ok, phone_number, country_code} <- Phone.parse_phone_number(params),
           {:ok, _} <- WhitelistedNumber.create_or_fetch_whitelisted_number(phone_number, country_code),
           {:ok, _} <- WhitelistedBrokerInfo.create(params, from_script?),
           {:ok, %Credential{profile_type_id: profile_type_id, broker_id: broker_id} = credential} <-
             Accounts.create_account_info(params, user_map),
           %{otp: otp} <-
             Otp.get_access_otp(credential.phone_number, profile_type_id) do
        if from_script? == false do
          employee_credential = EmployeeCredential.fetch_employee(params["assign_to"])
          AssignedBrokerHelper.create_employee_assignments(assigned_by_id, employee_credential.id, [broker_id])

          BnApis.Helpers.SmsHelper.send_broker_assigned_sms(employee_credential, %{
            broker_name: params["broker_name"],
            otp: otp
          })
        end

        %{message: "Successfully whitelisted", unique_code: '-'}
      else
        {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  1. Fetches broker from name
  """
  def fetch_broker(name) do
    Broker
    |> where(name: ^name)
    |> Repo.all()
    |> List.last()
  end

  def operating_city_changeset(broker, city_id) when is_binary(city_id),
    do: operating_city_changeset(broker, String.to_integer(city_id))

  def operating_city_changeset(broker, city_id) do
    broker
    |> change(operating_city: city_id)
  end

  def broker_type_changeset(broker, broker_type_id)
      when is_binary(broker_type_id),
      do: broker_type_changeset(broker, String.to_integer(broker_type_id))

  def broker_type_changeset(broker, broker_type_id) do
    broker
    |> change(broker_type_id: broker_type_id)
  end

  def info_changeset(broker, params) do
    city_id = params["city_id"]
    pan = params["pan"]

    broker =
      if !is_nil(pan) do
        broker |> change(pan: pan)
      else
        broker
      end

    broker =
      if !is_nil(city_id) do
        city_id = if is_binary(city_id), do: String.to_integer(city_id), else: city_id
        broker |> change(operating_city: city_id)
      else
        broker
      end

    polygon_id = params["polygon_id"]

    broker =
      if !is_nil(polygon_id) do
        polygon_id = if is_binary(polygon_id), do: String.to_integer(polygon_id), else: polygon_id
        broker |> change(polygon_id: polygon_id)
      else
        broker
      end

    is_cab_booking_enabled = params["is_cab_booking_enabled"]

    broker =
      if !is_nil(is_cab_booking_enabled) do
        is_cab_booking_enabled = is_cab_booking_enabled == "true"
        broker |> change(is_cab_booking_enabled: is_cab_booking_enabled)
      else
        broker
      end

    is_match_enabled = params["is_match_enabled"]

    broker =
      if !is_nil(is_match_enabled) do
        is_match_enabled = is_match_enabled == "true"
        broker |> change(is_match_enabled: is_match_enabled)
      else
        broker
      end

    max_rewards_per_day = params["max_rewards_per_day"]

    broker =
      if !is_nil(max_rewards_per_day) do
        broker |> change(max_rewards_per_day: max_rewards_per_day)
      else
        broker
      end

    broker = add_rera_to_broker_changeset(params["rera"], broker)
    broker = add_rera_name_to_broker_changeset(params["rera_name"], broker)
    broker
  end

  @doc """
    Move to a helper
    Supported option: allowed_extensions :: List
  """
  def validate_attachment(changeset, fields, options \\ []) do
    fields
    |> Enum.reduce(changeset, fn field_name, modified_changeset ->
      input = modified_changeset |> get_field(field_name)
      input_url = input["url"] || input[:url]
      allowed_extensions = options |> Keyword.get(:allowed_extensions)

      case FormHelper.validate_attachment(input_url, allowed_extensions) do
        false ->
          modified_changeset |> add_error(field_name, "is invalid")

        {false, error_messages} when is_list(error_messages) ->
          error_messages
          |> Enum.reduce(modified_changeset, fn error_message, mc ->
            mc |> add_error(field_name, error_message)
          end)

        {false, error_message} ->
          modified_changeset |> add_error(field_name, error_message)

        _ ->
          modified_changeset
      end
    end)
  end

  defp validate_if_pan_already_exist(changeset) do
    role_type_id = get_field(changeset, :role_type_id)
    pan = get_field(changeset, :pan)
    if role_type_id == dsa()["id"], do: validations_for_broker_pan(changeset, pan), else: changeset
  end

  def validations_for_broker_pan(changeset, nil), do: changeset

  def validations_for_broker_pan(changeset, pan) do
    broker_id = get_field(changeset, :id)

    case Utils.validate_pan(pan) do
      true ->
        if get_broker_count_using_pan(pan, broker_id) > 0, do: add_error(changeset, :pan, "User with the PAN number already exist"), else: changeset

      _ ->
        add_error(changeset, :pan, "Invalid PAN")
    end
  end

  def get_broker_count_using_pan(pan, broker_id) do
    query =
      Broker
      |> where([b], ilike(b.pan, ^pan))

    query = if is_nil(broker_id), do: query, else: query |> where([b], b.id != ^broker_id)

    query
    |> Repo.aggregate(:count, :id)
  end

  def upload_image_to_s3(profile_image, cred_uuid) do
    case profile_image do
      nil ->
        {:ok, nil}

      %Plug.Upload{
        content_type: _content_type,
        filename: filename,
        path: filepath
      } ->
        working_directory = "tmp/file_worker/#{cred_uuid}"
        File.mkdir_p!(working_directory)

        image_filepath = "#{working_directory}/#{filename}"

        File.cp(filepath, image_filepath)

        file = File.read!(image_filepath)
        md5 = file |> :erlang.md5() |> Base.encode16(case: :lower)
        key = "#{cred_uuid}/#{md5}/#{filename}"
        files_bucket = ApplicationHelper.get_files_bucket()
        {:ok, _message} = S3Helper.put_file(files_bucket, key, file)

        profile_image = %{
          url: key
        }

        # removes file working directory before returning
        File.rm_rf(working_directory)
        {:ok, profile_image}

      _ ->
        {:ok, nil}
    end
  end

  def upload_qr_code(credential) do
    credential = credential |> Repo.preload([:broker, :organization], force: true)

    timestamp = Time.now_to_epoch()
    secret_salt = ApplicationHelper.get_secret_salt()

    checksum =
      "#{credential.uuid} #{timestamp} #{secret_salt}"
      |> :erlang.md5()
      |> Base.encode16(case: :lower)

    qr_code_content =
      %{
        uuid: credential.uuid,
        name:
          (Map.has_key?(credential.broker || %{}, :name) &&
             credential.broker.name) || "NA",
        org_name:
          (Map.has_key?(credential.organization || %{}, :name) &&
             credential.organization.name) || "NA",
        timestamp: timestamp,
        checksum: checksum
      }
      |> Poison.encode!()

    {png_output, _} = System.cmd("ruby", ["scripts/rqrcode.rb", "#{qr_code_content}"])

    filepath = "/tmp/#{checksum}.png"
    File.write(filepath, png_output, [:binary])

    file = File.read!(filepath)
    key = "#{checksum}.png"
    files_bucket = ApplicationHelper.get_files_bucket()
    S3Helper.put_file(files_bucket, key, file)

    # removes file from tmp directory before returning
    File.rm(filepath)

    key
  end

  def update_profile_pic_changeset(params, credential) do
    {:ok, profile_image} = upload_image_to_s3(params["profile_image"], credential.uuid)
    qr_code_url = upload_qr_code(credential)

    Broker.changeset(credential.broker, %{
      "profile_image" => profile_image,
      "qr_code_url" => qr_code_url
    })
  end

  def update_pan_pic_changeset(params, credential) do
    {:ok, pan_image} = upload_image_to_s3(params["pan_image"], credential.uuid)

    Broker.changeset(credential.broker, %{
      "pan_image" => pan_image
    })
  end

  def update_rera_file_changeset(params, credential) do
    {:ok, rera_file} = upload_image_to_s3(params["rera_file"], credential.uuid)

    Broker.changeset(credential.broker, %{
      "rera_file" => rera_file
    })
  end

  def update_profile_changeset(params, credential, user_map) do
    fn ->
      credential_organization = credential.organization

      org_params = %{
        "name" => params["org_name"] || credential_organization.name,
        "gst_number" => params["gstin"] || credential_organization.gst_number,
        "rera_id" => params["rera_id"] || credential_organization.rera_id,
        "firm_address" => params["firm_address"] || credential_organization.firm_address,
        "place_id" => params["place_id"] || credential_organization.place_id
      }

      organization_changeset = Organization.changeset(credential_organization, org_params)

      organization =
        case Repo.update(organization_changeset) do
          {:ok, organization} ->
            organization

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      broker_params = %{}

      broker_params =
        if not is_nil(params["name"]) do
          broker_params |> Map.put("name", params["name"])
        else
          broker_params
        end

      broker_params =
        if not is_nil(params["pan"]) do
          broker_params |> Map.put("pan", params["pan"])
        else
          broker_params
        end

      broker_params =
        if not is_nil(params["rera"]) do
          broker_params |> Map.put("rera", params["rera"])
        else
          broker_params
        end

      broker_params = add_rera_name_to_params(params["rera_name"], broker_params)
      broker_changeset = Broker.changeset(credential.broker, broker_params)

      broker =
        case AuditedRepo.update(broker_changeset, user_map) do
          {:ok, broker} ->
            Exq.enqueue(
              Exq,
              "broker_kit_generator",
              BnApis.BrokerKitWorker,
              [broker.id]
            )

            broker

          {:error, changeset} ->
            Repo.rollback(changeset)
        end

      qr_code_url = Broker.upload_qr_code(credential)

      broker =
        Broker.changeset(broker, %{"qr_code_url" => qr_code_url})
        |> AuditedRepo.update(user_map)

      {broker, organization}
    end
  end

  def get_profile_image_url(broker) do
    case broker.profile_image do
      nil -> nil
      %{"url" => nil} -> nil
      %{"url" => url} -> S3Helper.get_imgix_url(url)
    end
  end

  def get_credential_data(broker) do
    case Repo.all(from(c in Credential, where: c.broker_id == ^broker.id))
         |> List.first() do
      nil ->
        %{}

      credential ->
        %{
          "phone_number" => credential.phone_number
        }
    end
  end

  def validate_rera(rera, rera_name, broker_id) do
    rera = rera |> parse_string()
    rera_name = rera_name |> parse_string()

    city_id =
      Broker
      |> where([b], b.id == ^broker_id)
      |> select([b], b.operating_city)
      |> Repo.one()

    valid_maharastra_city? = Enum.member?(@valid_cities_in_maharastra, city_id)

    case valid_maharastra_city? do
      true ->
        {valid_rera?, rera_file} = fetch_and_parse_rera_validation_response(rera, rera_name, city_id)

        case add_or_update_rera_to_db(valid_rera?, rera, rera_name, rera_file) do
          {:ok, _changeset} ->
            valid_rera?

          {:error, _changeset} ->
            false

          {_, _} ->
            false
        end

      false ->
        {valid_rera?, rera_file} = fetch_and_parse_rera_validation_response(rera, rera_name, city_id)

        ###
        ## Currently, for cities outside of Maharastra, we just want to store valid rera's
        ## and ignore any errors arising due to invalid rera's from these cities,
        ## hence we always return true here
        ###

        {_status, _changeset} = add_or_update_rera_to_db(valid_rera?, rera, rera_name, rera_file)
        true
    end

    ## Till the client side changes are done, we would always be returning true here
    ## TODO: Remove the below lines
    true
  end

  def filter_brokers_query(query, params) do
    where(query, ^filter_broker_params(params))
  end

  def filter_broker_params(filter) do
    Enum.reduce(filter, dynamic(true), fn
      {"city", cities}, dynamic when is_list(cities) ->
        dynamic([b], ^dynamic and b.operating_city in ^cities)

      {"city", cities}, dynamic when is_bitstring(cities) ->
        dynamic([b], ^dynamic and fragment("? in (?)", b.operating_city, ^cities))

      {"phone_number", phone_numbers}, dynamic when is_list(phone_numbers) ->
        dynamic([b, cred], ^dynamic and cred.phone_number in ^phone_numbers)

      _, dynamic ->
        dynamic
    end)
  end

  def update_broker_kyc_details(
        params = %{
          "pan" => _pan,
          "pan_image" => _pan_image,
          "name" => _name
        },
        broker_id,
        cred_id,
        user_map
      ) do
    with {:ok, broker} <- update_broker_pan_details(params, broker_id, user_map),
         {true, []} <- maybe_update_rera(params, broker, cred_id),
         {:ok, broker} <- update_broker_rera(params, broker, user_map) do
      {:ok, broker}
    else
      {false, []} ->
        {:error, "KYC with same details was already provided by you."}

      {false, conflicts} ->
        case OrgJoiningRequests.multiple_joining_request?(cred_id) do
          true -> {:error, @pending_request_message}
          false -> {:ok, conflicts}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def update_broker_kyc_details(_params, _broker_id, _cred_id, _user_map), do: {:error, "Invalid KYC params."}

  def parse_broker_pan_image(nil), do: nil
  def parse_broker_pan_image(%{url: url}), do: parse_broker_pan_image(url)
  def parse_broker_pan_image(%{"url" => url}), do: parse_broker_pan_image(url)

  def parse_broker_pan_image(url) when is_binary(url) do
    String.contains?(url, @imgix_domain)
    |> case do
      true -> url
      false -> S3Helper.get_imgix_url(url)
    end
  end

  def mark_kyc_as_approved(id, user_map) do
    broker = fetch_broker_from_id(id)

    cond do
      is_nil(broker) ->
        {:error, :not_found}

      broker ->
        broker
        |> changeset(%{kyc_status: :approved})
        |> AuditedRepo.update(user_map)
        |> maybe_send_kyc_push_notification()
    end
  end

  def mark_kyc_as_rejected(id, change_notes, user_map) do
    broker = fetch_broker_from_id(id)

    cond do
      is_nil(broker) ->
        {:error, :not_found}

      broker ->
        broker
        |> changeset(%{kyc_status: :rejected, change_notes: change_notes, rera: nil, rera_file: nil, rera_name: nil})
        |> AuditedRepo.update(user_map)
        |> maybe_send_kyc_push_notification()
    end
  end

  def fetch_broker_kyc_details(broker) do
    %{
      "rera" => broker.rera,
      "rera_name" => broker.rera_name,
      "rera_file" => broker.rera_file,
      "pan" => broker.pan,
      "pan_image" => parse_broker_pan_image(broker.pan_image),
      "kyc_status" => broker.kyc_status,
      "change_notes" => broker.change_notes,
      "is_pan_verified" => broker.is_pan_verified,
      "is_rera_verified" => broker.is_rera_verified,
      "show_kyc_screen" => should_show_kyc_screen(broker.id),
      "is_rera_required" => false,
      "is_kyc_skippable" => false
    }
  end

  defp should_show_kyc_screen(broker_id) do
    broker = fetch_broker_from_id(broker_id)
    kyc_status = broker.kyc_status

    cond do
      kyc_status == :approved -> false
      true -> true
    end
  end

  def maybe_update_rera(params, broker, cred_id) do
    rera = Map.get(params, "rera")
    rera = if is_nil(rera), do: nil, else: String.trim(rera)

    cred = Credential.get_credential_by_id(cred_id)

    find_conflicting_broker_orgs(rera, broker.id, cred.organization_id, broker.role_type_id)
    |> case do
      conflicting_rera_list when is_list(conflicting_rera_list) and length(conflicting_rera_list) > 0 ->
        conflicts =
          conflicting_rera_list
          |> Enum.map(fn record ->
            org_admin_cred = fetch_org_admin_cred(record.org_id, broker.id, rera)

            if not is_nil(org_admin_cred) do
              %{
                "org_name" => record.org_name,
                "org_address" => record.org_address,
                "org_id" => record.org_id,
                "admin_name" => parse_for_nil(org_admin_cred, :name),
                "admin_phone_number" => parse_for_nil(org_admin_cred, :phone_number),
                "admin_broker_id" => parse_for_nil(org_admin_cred, :broker_id),
                "admin_cred_id" => parse_for_nil(org_admin_cred, :cred_id),
                "admin_rera" => parse_for_nil(org_admin_cred, :rera)
              }
            end
          end)

        {false, Enum.filter(conflicts, &(!is_nil(&1)))}

      _ ->
        {true, []}
    end
  end

  def fetch_org_admin_cred(org_id, broker_id, rera \\ nil) do
    pending_admin_ids = OrgJoiningRequests.get_admin_ids_with_pending_requests()

    Broker
    |> join(:inner, [br], cred in assoc(br, :credentials))
    |> where([br, cred], cred.active == true and br.id != ^broker_id and cred.id not in ^pending_admin_ids)
    |> where([br, cred], cred.broker_role_id == ^BrokerRole.admin().id and cred.organization_id == ^org_id)
    |> filter_by_org_rera(rera)
    |> distinct(true)
    |> select([br, cred], %{
      cred_id: cred.id,
      broker_id: br.id,
      name: br.name,
      phone_number: cred.phone_number,
      rera: br.rera
    })
    |> limit(1)
    |> Repo.one()
  end

  def update_broker_rera(params, broker, user_map) do
    broker = fetch_broker_from_id(broker.id)

    rera = Map.get(params, "rera")
    rera = if is_nil(rera), do: nil, else: String.trim(rera)

    rera_name = Map.get(params, "rera_name")

    rera_file = Map.get(params, "rera_file")

    rera_file =
      if is_nil(rera_file) do
        nil
      else
        String.contains?(rera_file, @imgix_domain)
        |> case do
          true -> %{url: rera_file}
          false -> %{url: S3Helper.get_imgix_url(rera_file)}
        end
      end

    broker
    |> changeset(%{rera: rera, rera_file: rera_file, rera_name: rera_name})
    |> AuditedRepo.update(user_map)
    |> case do
      {:ok, broker} ->
        trigger_rera_validation(broker, user_map)
        {:ok, broker}

      {:error, error} ->
        {:error, error}
    end
  end

  def update_broker_pan_details(
        _params = %{
          "pan" => pan,
          "pan_image" => pan_image,
          "name" => name
        },
        broker_id,
        user_map
      ) do
    pan = String.trim(pan)
    name = String.trim(name)

    pan_image = %{
      url: parse_image_url(String.trim(pan_image))
    }

    broker = fetch_broker_from_id(broker_id)

    cond do
      Utils.validate_pan(pan) == false ->
        {:error, "Invalid PAN"}

      broker ->
        broker
        |> changeset(%{
          pan: pan,
          pan_image: pan_image,
          name: name
        })
        |> AuditedRepo.update(user_map)
        |> case do
          {:ok, broker} ->
            trigger_pan_validation(broker, user_map)
            {:ok, broker}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  def update_broker_pan_details(_params, _broker_id, _user_map), do: {:error, "Invalid KYC params."}

  defp trigger_pan_validation(broker, user_map) do
    pan = broker.pan
    pan_image_url = parse_broker_pan_image(broker.pan_image)

    {is_pan_verified, pan_name} =
      API.validate_pan_details(pan, pan_image_url, String.trim(broker.name))
      |> case do
        {:ok, true, pan_name} ->
          {true, pan_name}

        {:ok, false, pan_name} ->
          {false, pan_name}

        {:error, error} ->
          channel = ApplicationHelper.get_slack_channel()

          ApplicationHelper.notify_on_slack(
            "Error while Signzy PAN verification for broker: #{broker.name}, id: #{broker.id} - #{error}",
            channel
          )

          {false, nil}
      end

    # kyc_status = if is_pan_verified, do: :approval_pending, else: :rejected

    change_notes = if is_pan_verified, do: nil, else: @invalid_pan_error_message

    kyc_changes = %{
      kyc_status: :approval_pending,
      pan_name: pan_name,
      is_pan_verified: is_pan_verified,
      change_notes: change_notes
    }

    update_kyc_status(broker, kyc_changes, user_map)
  end

  defp trigger_rera_validation(broker, user_map) do
    {status, response} = ExternalApiHelper.validate_rera(broker.rera, broker.operating_city)

    is_rera_verified =
      case {status, response} do
        {200, response} -> Map.get(response, "is_valid", "false") |> Utils.parse_boolean_param()
        {_, _response} -> false
      end

    kyc_status = if is_rera_verified, do: :approval_pending, else: broker.kyc_status
    {rera_name, rera_file} = parse_rera_response(status, response)

    change_notes = if is_rera_verified, do: nil, else: @invalid_rera_error_message
    change_notes = if broker.kyc_status == :rejected, do: parse_failure_message(broker.change_notes, kyc_status), else: change_notes

    kyc_changes = %{
      kyc_status: kyc_status,
      is_rera_verified: is_rera_verified,
      rera_name: rera_name || broker.rera_name,
      rera_file: rera_file || broker.rera_file,
      change_notes: change_notes
    }

    update_kyc_status(broker, kyc_changes, user_map)
  end

  def update_kyc_status(broker, params, user_map) do
    broker
    |> changeset(params)
    |> AuditedRepo.update(user_map)
  end

  defp parse_rera_response(200, response) do
    rera_name = Map.get(response, "name")
    rera_file_url = Map.get(response, "rera_file_url")

    rera_file =
      if not is_nil(rera_file_url) do
        %{
          url: rera_file_url
        }
      else
        nil
      end

    {rera_name, rera_file}
  end

  defp parse_rera_response(_status, _response), do: {nil, nil}

  defp fetch_and_parse_rera_validation_response("", _, _city_id), do: {false, nil}
  defp fetch_and_parse_rera_validation_response(nil, _, _city_id), do: {false, nil}

  defp fetch_and_parse_rera_validation_response(_, "", _city_id), do: {false, nil}
  defp fetch_and_parse_rera_validation_response(_, nil, _city_id), do: {false, nil}

  defp fetch_and_parse_rera_validation_response(rera, rera_name, city_id) do
    {status, response} = ExternalApiHelper.validate_rera(rera, city_id)
    parse_rera_validation_response(status, response, rera, rera_name)
  end

  defp parse_rera_validation_response(200, response, rera, rera_name) do
    rera_file = parse_string(Map.get(response, "rera_file_url"))
    file_rera_id = parse_string(Map.get(response, "rera_number"))
    file_rera_name = parse_string(Map.get(response, "name"))

    validate_rera_details_from_rera_file(rera_file, rera == file_rera_id, file_rera_name == rera_name)
  end

  defp parse_rera_validation_response(_, _response, _rera, _rera_name), do: {false, nil}

  defp validate_rera_details_from_rera_file(nil, _valid_rera_id?, _valid_rera_name?), do: {false, nil}

  defp validate_rera_details_from_rera_file(rera_file, true, true), do: {true, rera_file}

  defp validate_rera_details_from_rera_file(rera_file, _, _), do: {false, rera_file}

  defp parse_string(nil), do: nil

  defp parse_string(string), do: String.trim(string) |> String.downcase()

  defp add_or_update_rera_to_db(true, rera, rera_name, rera_file) do
    case ValidRera.fetch(rera) do
      nil ->
        ValidRera.create(rera, rera_name, rera_file)

      valid_rera ->
        ValidRera.update(valid_rera, rera, rera_name, rera_file)
    end
  end

  defp add_or_update_rera_to_db(false, _rera, _rera_name, _rera_file), do: {nil, nil}

  @doc """
  1. Read the contents of file from the given path
  2. upload the file content with the newly generated path key
  3. Return that s3 path
  """
  def upload_personalised_kit(file_path, user_uuid, orientation) do
    file = file_path |> File.read!()
    files_bucket = ApplicationHelper.get_files_bucket()
    random_suffix = SecureRandom.urlsafe_base64(8)

    s3_path = "personalised_kit/#{orientation}/#{user_uuid}/#{random_suffix}.pdf"

    S3Helper.put_file(files_bucket, s3_path, file)
    s3_path
  end

  defp parse_image_url(url) when url in [nil, ""], do: nil
  defp parse_image_url(url) when is_binary(url), do: S3Helper.parse_file_url(String.contains?(url, @imgix_domain), url, @imgix_domain)

  defp whitelist_broker_params(nil, _params, _created_by_id, false = _from_script?),
    do: {:error, "Invalid polygon uuid"}

  defp whitelist_broker_params(polygon, params, created_by_id, from_script?) do
    params
    |> Map.merge(%{
      "created_by_id" => created_by_id,
      "panel_auto_created" => true,
      "assign_to" => params["assign_to"],
      "assign_to_list" => params["assign_to_list"],
      "is_match_enabled" => params["is_match_enabled"],
      "country_code" => Map.get(params, "country_code") || "+91"
    })
    |> Map.merge(add_polygon_data(polygon, from_script?))
  end

  defp add_polygon_data(_polygon, true = _from_script?), do: %{"polygon_id" => nil, "operating_city" => nil}

  defp add_polygon_data(polygon, false = _from_script?),
    do: %{"polygon_id" => polygon.id, "operating_city" => polygon.city_id}

  defp add_rera_name_to_params(nil, broker_params), do: broker_params

  defp add_rera_name_to_params(rera_name, broker_params), do: broker_params |> Map.put("rera_name", rera_name)

  defp add_rera_to_broker_changeset(nil, broker), do: broker

  defp add_rera_to_broker_changeset(rera, broker), do: Broker.changeset(broker, %{rera: rera})

  defp add_rera_name_to_broker_changeset(nil, broker), do: broker

  defp add_rera_name_to_broker_changeset(rera_name, broker), do: Broker.changeset(broker, %{rera_name: rera_name})

  def get_broker_details(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)
    image_url = get_profile_image_url(broker)
    credentials = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload(:organization)

    %{
      "broker_name" => broker.name,
      "broker_organization" => credentials.organization.name,
      "broker_address" => credentials.organization.firm_address,
      "phone_number" => credentials.phone_number,
      "broker_id" => broker_id,
      "image_url" => image_url
    }
  end

  def get_broker_details_using_cred_id(credential_id) do
    credentials = Repo.get_by(Credential, id: credential_id) |> Repo.preload(:broker)

    %{
      "broker_name" => credentials.broker.name,
      "phone_number" => credentials.phone_number
    }
  end

  def create_broker_map(nil), do: nil

  def create_broker_map(broker) do
    broker_credential = Credential |> where([c], c.broker_id == ^broker.id and c.active == true) |> Repo.all() |> List.last()

    broker_phone_number = if is_nil(broker_credential), do: nil, else: broker_credential.phone_number
    broker_fcm_id = if is_nil(broker_credential), do: nil, else: broker_credential.fcm_id

    %{
      "name" => broker.name,
      "operating_city" => broker.operating_city,
      "broker_phone_number" => broker_phone_number,
      "broker_fcm_id" => broker_fcm_id,
      "role_type" => parse_role_type_id(broker.role_type_id),
      "role_type_id" => broker.role_type_id
    }
  end

  def find_or_create_broker(broker_name, phone_number, country_code, organization_id, user_map) do
    Repo.transaction(fn ->
      case create_or_get_broker(%{"broker_name" => broker_name}, user_map) do
        {:ok, broker} ->
          credential_params = %{
            "phone_number" => phone_number,
            "country_code" => country_code,
            "broker_id" => broker.id,
            "organization_id" => organization_id
          }

          case Credential.create_or_get_credential(credential_params, user_map) do
            {:ok, credential} -> credential
            {:error, error} -> Repo.rollback(error)
          end

          broker

        {:error, error} ->
          Repo.rollback(error)
      end
    end)
  end

  def broker_type_using_phone_number(phone_number) do
    credential = Repo.get_by(Credential, phone_number: phone_number, country_code: "+91", active: true)
    credential = credential |> Repo.preload(:broker)
    credential.broker.role_type_id
  end

  def broker_type_using_broker_id(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)
    broker.role_type_id
  end

  def mark_hl_tnc_read(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)

    Broker.changeset(broker, %{
      homeloans_tnc_agreed: true
    })
    |> Repo.update()
  end

  def get_hl_tnc_agreed(broker_id) do
    broker = Repo.get_by(Broker, id: broker_id)
    broker.homeloans_tnc_agreed
  end

  def update_broker_status(broker_id, status, rejected_reason, user_map) do
    case Repo.get_by(Broker, id: broker_id, role_type_id: dsa()["id"]) do
      nil ->
        {:error, :not_found}

      broker ->
        case Enum.member?([pending()["name"], approved()["name"], rejected()["name"]], status) do
          false ->
            {:error, "Invalid status"}

          true ->
            status_id = get_status_id(status)

            broker
            |> Broker.changeset(%{hl_commission_status: status_id, hl_commission_rej_reason: rejected_reason})
            |> AuditedRepo.update(user_map)

            {:ok, "Updated Successfully"}
        end
    end
  end

  def get_profile_details(credential_uuid) do
    profile_type_id = ProfileType.broker().id
    {:ok, Token.create_token_data(credential_uuid, profile_type_id, true)}
  end

  defp parse_role_type_id(nil), do: nil

  defp parse_role_type_id(role_type_id) do
    cond do
      role_type_id == real_estate_broker()["id"] -> real_estate_broker()["name"]
      role_type_id == dsa()["id"] -> dsa()["name"]
      true -> nil
    end
  end

  def is_whitelisting_approved(phone_number) do
    credential = Credential.fetch_credential(phone_number, "+91", [:broker])

    invites =
      Invite.new_invites_query(phone_number, "+91")
      |> Invite.invite_select_query()
      |> Repo.all()

    cond do
      not is_nil(invites) and length(invites) > 0 ->
        {:ok}

      credential == nil ->
        {:error, "User not found"}

      credential.broker.role_type_id == Broker.dsa()["id"] and credential.broker.hl_commission_status != approved()["id"] ->
        {:error, "Your whitelisting has not been approved by admin"}

      true ->
        {:ok}
    end
  end

  defp restrict_kyc_details_change(changeset = %{valid?: true}) do
    kyc_status = get_field(changeset, :kyc_status) |> parse_kyc_state()
    name_change? = not is_nil(Map.get(changeset.changes, :name))
    pan_change? = not is_nil(Map.get(changeset.changes, :pan))

    if kyc_status == :approved and (name_change? || pan_change?), do: add_error(changeset, :pan, "details change not allowed after KYC is approved."), else: changeset
  end

  defp restrict_kyc_details_change(changeset), do: changeset

  defp validate_kyc_state_change(changeset = %{valid?: true}, old_state) do
    new_state = get_field(changeset, :kyc_status) |> parse_kyc_state()

    if valid_state_change(old_state, new_state),
      do: changeset,
      else: add_error(changeset, :status, "Cannot change KYC state from #{old_state} to #{new_state}")
  end

  defp validate_kyc_state_change(changeset, _old_state), do: changeset

  defp parse_kyc_state(nil), do: nil
  defp parse_kyc_state(""), do: nil
  defp parse_kyc_state(state) when is_binary(state), do: String.to_atom(state)
  defp parse_kyc_state(state), do: state

  defp valid_state_change(state, state) when not is_nil(state), do: true
  defp valid_state_change(old_state, new_state), do: @valid_status_change[old_state] |> Enum.any?(&(&1 == new_state))

  defp maybe_send_kyc_push_notification({:ok, broker}) do
    send_kyc_push_notification(broker.id, broker.kyc_status)
    {:ok, broker}
  end

  defp maybe_send_kyc_push_notification({:error, error}), do: {:error, error}

  defp send_kyc_push_notification(broker_id, kyc_status) do
    broker_credential =
      Credential
      |> where([cred], cred.broker_id == ^broker_id)
      |> Repo.all()
      |> Utils.get_active_fcm_credential()

    if not is_nil(broker_credential) do
      {data, type} = get_push_notification_text(kyc_status)
      trigger_push_notification(broker_credential, %{"data" => data, "type" => type})
    end
  end

  defp get_push_notification_text(kyc_status) do
    title = "Broker Network KYC"
    message = parse_message_by_kyc_status(kyc_status)
    intent = "com.dialectic.brokernetworkapp.actions.PROFILE"
    type = "GENERIC_NOTIFICATION"
    data = %{"title" => title, "message" => message, "intent" => intent}
    {data, type}
  end

  def parse_message_by_kyc_status(:approved), do: "Your KYC is approved, you may now use all the features"
  def parse_message_by_kyc_status(:rejected), do: "Your KYC is rejected, please resubmit your correct details"

  defp trigger_push_notification(broker_credential, notif_data = %{"data" => _data, "type" => _type}) do
    Exq.enqueue(Exq, "broker_kyc_notification", BnApis.Notifications.PushNotificationWorker, [
      broker_credential.fcm_id,
      notif_data,
      broker_credential.id,
      broker_credential.notification_platform
    ])
  end

  def find_conflicting_broker_orgs(nil, _broker_id, _org_id, _role_type_id), do: []
  def find_conflicting_broker_orgs("", _broker_id, _org_id, _role_type_id), do: []

  def find_conflicting_broker_orgs(rera, broker_id, org_id, role_type_id) do
    Broker
    |> join(:inner, [br], cred in assoc(br, :credentials))
    |> join(:inner, [br, cred], org in assoc(cred, :organization))
    |> where([br, cred, org], br.id != ^broker_id and ilike(br.rera, ^rera) and cred.active == true and br.role_type_id == ^role_type_id)
    |> filter_by_org_id(org_id)
    |> distinct([br, cred, org], org.id)
    |> select([br, cred, org], %{
      org_id: org.id,
      org_name: org.name,
      org_address: org.firm_address
    })
    |> Repo.all()
  end

  defp parse_for_nil(nil, _key), do: nil
  defp parse_for_nil(record, key), do: Map.get(record, key)

  defp parse_failure_message(change_notes, :rejected), do: change_notes <> ", " <> @invalid_rera_error_message
  defp parse_failure_message(change_notes, _kyc_status), do: change_notes

  defp filter_by_kyc_status(query, kyc_status) when kyc_status in ["", nil], do: query

  defp filter_by_kyc_status(query, kyc_status) when is_atom(kyc_status) do
    query
    |> where([b, c, o, p, m], b.kyc_status == ^kyc_status)
  end

  defp filter_by_kyc_status(query, _kyc_status), do: query

  defp filter_by_org_rera(query, rera) when rera in ["", nil], do: query

  defp filter_by_org_rera(query, rera) do
    query
    |> where([br, cred], ilike(br.rera, ^rera))
  end

  defp filter_by_org_id(query, nil), do: query

  defp filter_by_org_id(query, org_id) do
    query
    |> where([br, cred, org], org.id != ^org_id)
  end

  def fetch_brokers_with_no_og_employee(params) do
    page = (params["p"] && params["p"]) || 1
    size = 30
    brokers_with_og_employee_assigned = get_brokers_with_og_employee_assigned()

    query =
      Broker
      |> join(:inner, [b], rl in RewardsLead, on: b.id == rl.broker_id)
      |> join(:inner, [b, rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id and rls.status_id == ^Status.get_status_id("in_review"))
      |> join(:inner, [b, rl, rls], c in Credential, on: c.broker_id == b.id and c.active == true)
      |> join(:inner, [b, rl, rls, c], o in Organization, on: c.organization_id == o.id)
      |> join(:inner, [b, rl, rls, c, o], p in Polygon, on: p.id == b.polygon_id)
      |> join(:inner, [b, rl, rls, c, o, p], m in MatchPlus, on: m.broker_id == b.id)
      |> distinct([b, rl, rls, c, o, p, m], b.id)
      |> where([b, rl, rls, c, o, p, m], b.id not in ^brokers_with_og_employee_assigned)

    brokers =
      query
      |> select([b, rl, rls, c, o, p, m], %{
        active: c.active,
        phone_number: c.phone_number,
        app_version: c.app_version,
        manufacturer: c.device_manufacturer,
        model: c.device_model,
        os_version: c.device_os_version,
        last_active_at: c.last_active_at,
        id: b.id,
        name: b.name,
        polygon_id: b.polygon_id,
        polygon_name: p.name,
        app_installed: c.installed,
        profile_image: b.profile_image,
        operating_city: b.operating_city,
        broker_type_id: b.broker_type_id,
        is_cab_booking_enabled: b.is_cab_booking_enabled,
        is_match_enabled: b.is_match_enabled,
        is_match_plus_active: m.status_id == 1,
        is_pan_verified: b.is_pan_verified,
        is_rera_verified: b.is_rera_verified,
        inserted_at: b.inserted_at,
        organization_id: o.id,
        organization_uuid: o.uuid,
        organization_name: o.name,
        max_rewards_per_day: b.max_rewards_per_day,
        rera: b.rera,
        rera_name: b.rera_name,
        rera_file: b.rera_file,
        uuid: c.uuid,
        role_type_id: b.role_type_id,
        homeloans_tnc_agreed: b.homeloans_tnc_agreed,
        hl_commission_status: b.hl_commission_status,
        hl_commission_rej_reason: b.hl_commission_rej_reason,
        pan: b.pan,
        pan_image: b.pan_image,
        kyc_status: b.kyc_status,
        change_notes: b.change_notes
      })
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> order_by([b], asc: b.name)
      |> Repo.all()
      |> Enum.map(fn b ->
        broker_commission_details = get_broker_commission_details(b.id, b.role_type_id)
        assigned_emp_details = get_assigned_emp_details(b.id)
        phone_number = encrypt_broker_phone_number(b.phone_number, params["role_type_id"])
        Map.merge(b, %{broker_commission_details: broker_commission_details, assigned_emp_details: assigned_emp_details, phone_number: phone_number})
      end)

    total_count = query |> Repo.aggregate(:count, :id)
    has_more_brokers = page < Float.ceil(total_count / size)
    {brokers, has_more_brokers, total_count}
  end

  defp get_brokers_with_og_employee_assigned() do
    Broker
    |> join(:inner, [b], rl in RewardsLead, on: b.id == rl.broker_id)
    |> join(:inner, [b, rl], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id and rls.status_id == ^Status.get_status_id("in_review"))
    |> join(:inner, [b, rl, rls], ab in AssignedBrokers, on: b.id == ab.broker_id and ab.active == true)
    |> join(:inner, [b, rl, rls, ab], e in EmployeeCredential, on: ab.employees_credentials_id == e.id)
    |> where([b, rl, rls, ab, e], e.vertical_id == ^@project_vertical_id)
    |> distinct([b], b.id)
    |> select([b], b.id)
    |> Repo.all()
  end
end
