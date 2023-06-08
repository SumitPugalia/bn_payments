defmodule BnApis.Accounts.EmployeeCredential do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.AssignedBrokers
  alias BnApis.Accounts.{EmployeeRole, EmployeeCredential, Credential, EmployeeVertical}
  alias BnApis.Accounts.Schema.PayoutMapping
  alias BnApis.Helpers.{S3Helper, ApplicationHelper, AuditedRepo, Utils}
  alias BnApis.Places.City
  alias BnApis.Organizations.Broker

  schema "employees_credentials" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:phone_number, :string)
    field :country_code, :string, default: "+91"
    field(:email, :string)
    field(:name, :string)
    field(:employee_code, :string)
    field(:profile_image_url, :string)
    field(:active, :boolean, default: false)
    field(:last_active_at, :naive_datetime)
    field(:skip_allowed, :boolean, default: false)
    field(:hl_lead_allowed, :boolean, default: false)
    field(:razorpay_contact_id, :string)
    field(:razorpay_fund_account_id, :string)
    field(:access_city_ids, {:array, :integer})
    field(:sendbird_user_id, :string)
    field(:upi_id, :string)
    field(:fcm_id, :string)
    field(:notification_platform, :string)
    field(:pan, :string)

    belongs_to(:vertical, EmployeeVertical)
    belongs_to :reporting_manager, EmployeeCredential
    belongs_to(:employee_role, EmployeeRole)
    belongs_to(:city, City)

    has_many(:payout_mapping, PayoutMapping, foreign_key: :cilent_uuid, references: :uuid)

    timestamps()
  end

  @required_fields [
    :name,
    :phone_number,
    :country_code,
    :employee_code,
    :email,
    :city_id,
    :reporting_manager_id,
    :access_city_ids,
    :vertical_id
  ]
  @fields @required_fields ++
            [
              :profile_image_url,
              :active,
              :last_active_at,
              :employee_role_id,
              :razorpay_contact_id,
              :razorpay_fund_account_id,
              :hl_lead_allowed,
              :sendbird_user_id,
              :upi_id,
              :notification_platform,
              :fcm_id,
              :pan
            ]

  @doc false
  def changeset(employee_credential, attrs) do
    employee_credential
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:employee_role_id)
    |> validate_if_pan_already_exist()
  end

  defp validate_if_pan_already_exist(changeset) do
    pan = get_field(changeset, :pan)

    if(not is_nil(pan) and String.trim(pan) != "") do
      if(not Utils.validate_pan(pan), do: add_error(changeset, :pan, "Invalid PAN"), else: changeset)
    else
      changeset
    end
  end

  def fcm_changeset(emp_credential, fcm_id, platform) do
    emp_credential
    |> change(fcm_id: fcm_id)
    |> change(notification_platform: platform)
  end

  def all_employees do
    EmployeeCredential |> order_by(asc: :employee_role_id) |> Repo.all()
  end

  def all_active_employees do
    EmployeeCredential
    |> where(active: true)
    |> order_by(asc: :employee_role_id)
    |> Repo.all()
  end

  def paginated_active_employees(params) do
    limit = (params["size"] || "30") |> String.to_integer()
    page_no = (params["p"] || "1") |> String.to_integer()
    offset = (page_no - 1) * limit
    vertical_id = params["vertical_id"]

    employee_credentials = EmployeeCredential

    employee_credentials =
      if params["active"] == "false" do
        employee_credentials
      else
        employee_credentials |> where([ec], ec.active == true)
      end

    employee_credentials =
      if not is_nil(params["employee_role_id"]) do
        employee_role_id =
          if is_binary(params["employee_role_id"]),
            do: params["employee_role_id"] |> String.to_integer(),
            else: params["employee_role_id"]

        employee_credentials |> where([ec], ec.employee_role_id == ^employee_role_id)
      else
        employee_credentials
      end

    employee_credentials =
      if not is_nil(vertical_id) do
        vertical_id =
          if is_binary(vertical_id),
            do: Utils.parse_to_integer(vertical_id),
            else: vertical_id

        employee_credentials |> where([ec], ec.vertical_id == ^vertical_id and ec.active == true)
      else
        employee_credentials
      end

    employee_credentials =
      employee_credentials
      |> offset(^offset)
      |> limit(^(limit + 1))
      |> order_by(desc: :id)
      |> Repo.all()

    %{
      employees: Enum.take(employee_credentials, limit),
      has_next_page: length(employee_credentials) > limit
    }
  end

  def employee_performance_metrics(employee_credential_id) do
    assigned_broker_ids = BnApis.AssignedBrokers.fetch_all_active_assigned_brokers(employee_credential_id)

    %{
      no_of_assigned_brokers: length(assigned_broker_ids),
      no_of_posts_created: BnApis.Posts.assigned_posts_count_for_brokers(assigned_broker_ids),
      no_of_sv_approved: BnApis.Rewards.approved_reward_leads_count(assigned_broker_ids),
      no_of_hl_lead_created: BnApis.Homeloans.homeloan_leads_count(assigned_broker_ids)
    }
  end

  def search_employees(params) do
    limit = 30
    q = params["q"]
    name_query = "%#{String.downcase(q)}%"

    employee_credentials = EmployeeCredential

    employee_credentials =
      if params["active"] == "false" do
        employee_credentials
      else
        employee_credentials |> where([l], l.active == true)
      end

    employee_credentials =
      if not is_nil(params["employee_role_id"]) do
        employee_role_id =
          if is_binary(params["employee_role_id"]),
            do: params["employee_role_id"] |> String.to_integer(),
            else: params["employee_role_id"]

        employee_credentials |> where([l], l.employee_role_id == ^employee_role_id)
      else
        employee_credentials
      end

    employee_credentials =
      if not is_nil(params["vertical_id"]) do
        vertical_id = Utils.parse_to_integer(params["vertical_id"])
        employee_credentials |> where([l], l.vertical_id == ^vertical_id)
      else
        employee_credentials
      end

    employee_credentials =
      employee_credentials
      |> join(:left, [l], a in AssignedBrokers, on: l.id == a.employees_credentials_id and a.active == true)
      |> join(:left, [l, a], c in Credential, on: c.broker_id == a.broker_id)
      |> where(
        [l, a, c],
        l.phone_number == ^q or c.phone_number == ^q or fragment("LOWER(?) LIKE ?", l.name, ^name_query)
      )
      |> group_by([l, a, c], l.id)
      |> limit(^limit)
      |> Repo.all()

    %{
      employees: employee_credentials
    }
  end

  def create_employee_credential(params, user_map) do
    params |> signup_user(user_map)
  end

  def get_id_from_uuid(uuid) do
    employee_credential = uuid |> fetch_employee()
    employee_credential.id
  end

  @doc """
  1. Fetches active credential from phone number
  """
  def fetch_employee_credential(phone_number, country_code) do
    EmployeeCredential
    |> where([cred], cred.phone_number == ^phone_number and cred.active == true and cred.country_code == ^country_code)
    |> Repo.one()
  end

  def fetch_employee_by_id(id) do
    EmployeeCredential |> Repo.get_by(id: id)
  end

  def fetch_employee(uuid) do
    EmployeeCredential |> Repo.get_by(uuid: uuid)
  end

  def fetch_employee_credential_by_email(email) do
    EmployeeCredential
    |> where([cred], cred.email == ^email and cred.active == true)
    |> Repo.one()
  end

  def update_hl_flag(employee_id, flag, user_map) do
    employee = Repo.get(EmployeeCredential, employee_id)

    if(not is_nil(employee) and employee.hl_lead_allowed != flag) do
      changeset = EmployeeCredential.changeset(employee, %{"hl_lead_allowed" => flag})
      AuditedRepo.update(changeset, user_map)
    else
      {:ok, nil}
    end
  end

  def upload_image_to_s3(profile_image, phone_number) do
    case profile_image do
      nil ->
        {:ok, nil}

      %Plug.Upload{
        content_type: _content_type,
        filename: filename,
        path: filepath
      } ->
        working_directory = "tmp/file_worker/#{phone_number}"
        File.mkdir_p!(working_directory)

        image_filepath = "#{working_directory}/#{filename}"

        File.cp(filepath, image_filepath)

        file = File.read!(image_filepath)
        md5 = file |> :erlang.md5() |> Base.encode16(case: :lower)
        key = "#{phone_number}/#{md5}/#{filename}"
        files_bucket = ApplicationHelper.get_files_bucket()
        {:ok, _message} = S3Helper.put_file(files_bucket, key, file)

        # removes file working directory before returning
        File.rm_rf(working_directory)
        {:ok, key}

      _ ->
        {:ok, nil}
    end
  end

  def signup_user(
        params = %{
          "name" => name,
          "phone_number" => phone_number,
          "country_code" => country_code,
          "employee_role_id" => employee_role_id,
          "email" => email,
          "employee_code" => employee_code,
          "city_id" => city_id,
          "reporting_manager_id" => reporting_manager_id,
          "access_city_ids" => access_city_ids
          # "profile_image" => profile_image # Not Mandatory
        },
        user_map
      ) do
    {:ok, uploaded_image_url} = upload_image_to_s3(params["profile_image"], phone_number)

    employee_credential_attrs = %{
      phone_number: phone_number,
      country_code: country_code,
      name: name,
      employee_role_id: if(employee_role_id == 3, do: 1, else: employee_role_id),
      email: email,
      employee_code: employee_code,
      active: true,
      profile_image_url: uploaded_image_url,
      city_id: city_id,
      reporting_manager_id: reporting_manager_id,
      access_city_ids: access_city_ids,
      vertical_id: params["vertical_id"] || EmployeeVertical.default_vertical_id(),
      upi_id: params["upi_id"],
      pan: params["pan"]
    }

    employee_credential_changeset = changeset(%EmployeeCredential{}, employee_credential_attrs)

    case employee_credential_changeset.valid? do
      true ->
        case employee_credential_changeset |> AuditedRepo.insert(user_map) do
          {:ok, employee_credential} ->
            case maybe_add_as_dsa(employee_role_id, employee_credential) do
              {:ok, _} ->
                registerHLAgentOnsendBird(employee_credential, employee_role_id)
                {:ok, employee_credential}

              {:error, error} ->
                {:error, error}

              nil ->
                {:ok, employee_credential}
            end

          {:error, changeset} ->
            {:error, changeset}
        end

      false ->
        {:error, employee_credential_changeset}
    end
  end

  defp maybe_add_as_dsa(employee_role_id, employee) when employee_role_id in [29, 20, 31] do
    dsa = Repo.get_by(Credential, phone_number: employee.phone_number, active: true)

    case dsa do
      nil ->
        Repo.transaction(fn ->
          dsa_params = %{
            "name" => employee.name,
            "role_type_id" => 2,
            "operating_city" => employee.city_id,
            "pan" => employee.pan,
            "email" => employee.email,
            "hl_commission_status" => 2,
            "is_employee" => true
          }

          %Broker{}
          |> Broker.changeset(dsa_params)
          |> Repo.insert()
          |> case do
            {:ok, broker} ->
              add_employee_assigned_broker(employee.id, broker.id)
              add_entry_in_credentials_table(employee.phone_number, nil, broker.id)

            {:error, error} ->
              Repo.rollback(error)
          end
        end)

      _dsa ->
        Repo.rollback("DSA already registered")
    end
  end

  defp maybe_add_as_dsa(_employee_role_id, _employee_credential), do: nil

  def add_entry_in_credentials_table(dsa_phone_number, organization_id, broker_id) do
    credential_params = %{
      "phone_number" => dsa_phone_number,
      "organization_id" => organization_id,
      "broker_id" => broker_id,
      "profile_type_id" => 1,
      "country_code" => "+91",
      "active" => true
    }

    %Credential{}
    |> Credential.changeset(credential_params)
    |> Repo.insert do
    end
  end

  def add_employee_assigned_broker(employee_id, broker_id) do
    assigned_broker_params = %{
      "broker_id" => broker_id,
      "employees_credentials_id" => employee_id,
      "active" => true
    }

    case %AssignedBrokers{} |> AssignedBrokers.changeset(assigned_broker_params) |> Repo.insert() do
      {:ok, _} ->
        nil

      {:error, error} ->
        Repo.rollback(error)
    end
  end

  def registerHLAgentOnsendBird(employee_credential, employee_role_id) do
    cond do
      employee_role_id == EmployeeRole.hl_agent().id ->
        Exq.enqueue(Exq, "sendbird", BnApis.RegisterHlAgentOnSendbird, [get_sendbird_payload_hl(employee_credential)])

      employee_role_id == EmployeeRole.dsa_agent().id ->
        Exq.enqueue(Exq, "sendbird", BnApis.RegisterHlAgentOnSendbird, [get_sendbird_payload_dsa_agent(employee_credential)])

      true ->
        nil
    end
  end

  def update_profile_pic_changeset(credential, params) do
    {:ok, uploaded_image_url} = upload_image_to_s3(params["profile_image"], credential.phone_number)

    credential |> changeset(%{"profile_image_url" => uploaded_image_url})
  end

  def update_profile_changeset(credential, _params = %{"name" => name}) do
    credential |> changeset(%{"name" => name})
  end

  def update_employee_profile_changeset(
        credential,
        params = %{
          "name" => name,
          "phone_number" => phone_number,
          "employee_role_id" => employee_role_id,
          "email" => email,
          "employee_code" => employee_code,
          "city_id" => city_id,
          "reporting_manager_id" => reporting_manager_id,
          "access_city_ids" => access_city_ids,
          "country_code" => country_code,
          "vertical_id" => vertical_id
        }
      ) do
    # disallow updating super role
    if employee_role_id == 3 do
      credential
      |> changeset(%{
        "name" => name,
        "phone_number" => phone_number,
        "email" => email,
        "employee_code" => employee_code,
        "city_id" => city_id,
        "reporting_manager_id" => reporting_manager_id,
        "access_city_ids" => access_city_ids,
        "country_code" => country_code,
        "vertical_id" => vertical_id
      })
    else
      credential
      |> changeset(%{
        "name" => name,
        "phone_number" => phone_number,
        "employee_role_id" => employee_role_id,
        "email" => email,
        "employee_code" => employee_code,
        "city_id" => city_id,
        "reporting_manager_id" => reporting_manager_id,
        "access_city_ids" => access_city_ids,
        "country_code" => country_code,
        "vertical_id" => vertical_id,
        "pan" => params["pan"]
      })
    end
  end

  def update_active_changeset(credential, status) do
    credential
    |> change(active: status)
  end

  def razorpay_changeset(
        employee_credential,
        upi_id,
        razorpay_contact_id,
        razorpay_fund_account_id
      ) do
    employee_credential
    |> change(upi_id: upi_id)
    |> change(razorpay_contact_id: razorpay_contact_id)
    |> change(razorpay_fund_account_id: razorpay_fund_account_id)
  end

  def fetch_random_data_cleaner_id() do
    role_ids = [
      EmployeeRole.quality_controller().id,
      EmployeeRole.super().id,
      EmployeeRole.admin().id
    ]

    EmployeeCredential
    |> where([c], c.employee_role_id in ^role_ids)
    |> order_by(fragment("RANDOM()"))
    |> limit(1)
    |> select([c], c.id)
    |> Repo.one()
  end

  @spec fetch_payout_metadata(Ecto.UUID.t()) :: nil | map()
  def fetch_payout_metadata(credential_uuid) do
    query =
      from(p in PayoutMapping,
        join: c in EmployeeCredential,
        on: c.uuid == p.cilent_uuid,
        join: g in assoc(p, :payment_gateway),
        on: p.active == g.active,
        where: c.city_id in g.city_ids and p.active == true and c.uuid == ^credential_uuid,
        select: %{contact_id: p.contact_id, fund_account_id: p.fund_account_id, name: g.name}
      )

    # There should not be more than one active payout method
    Repo.one(query)
  end

  def get_sendbird_payload_hl(emp_credential) do
    %{
      "nickname" => "Home Loan Manager",
      "profile_url" => S3Helper.get_imgix_url("hl_profile_pic.png"),
      "user_id" => emp_credential.uuid,
      "metadata" => %{
        # Todo-> profile pic to be changed
        "phone_number" => ApplicationHelper.get_hl_manager_phone_number()
      }
    }
  end

  def get_sendbird_payload_dsa_agent(emp_credential) do
    %{
      "nickname" => "Loan Manager",
      "profile_url" => S3Helper.get_imgix_url("hl_profile_pic.png"),
      "user_id" => emp_credential.uuid,
      "metadata" => %{
        # Todo-> profile pic to be changed
        "phone_number" => ApplicationHelper.get_hl_manager_phone_number()
      }
    }
  end

  def get_employee_details(nil), do: nil
  def get_employee_details(emp_cred = %EmployeeCredential{}), do: Map.take(emp_cred, ~w(id name phone_number)a)

  def get_employee_name(nil), do: nil

  def get_employee_name(employee_id) do
    emp_cred = EmployeeCredential.fetch_employee_by_id(employee_id)

    case emp_cred do
      nil -> nil
      emp_cred -> emp_cred.name
    end
  end

  def fetch_employee_details(nil), do: %{}

  def fetch_employee_details(employee_id) do
    employee = fetch_employee_by_id(employee_id)

    (not is_nil(employee) and
       %{
         employee_uuid: employee.uuid,
         employee_id: employee.id,
         name: employee.name,
         phone_number: employee.phone_number,
         city_id: employee.city_id,
         employee_role_id: employee.employee_role_id
       }) || %{}
  end

  def get_reporter_ids(user_id) when is_integer(user_id), do: get_reporter_ids([user_id])

  def get_reporter_ids(user_ids) do
    EmployeeCredential
    |> where([ec], ec.reporting_manager_id in ^user_ids and ec.active == true)
    |> select([ec], ec.id)
    |> Repo.all()
  end

  def get_reporter_uuids(user_id, q \\ nil) do
    query =
      EmployeeCredential
      |> where([ec], ec.reporting_manager_id == ^user_id)
      |> where([ec], ec.active == true)

    query =
      if(not is_nil(q) and String.trim(q) != "") do
        formatted_query = "%#{String.downcase(String.trim(q))}%"
        query |> where([ec], fragment("LOWER(?) LIKE ?", ec.name, ^formatted_query))
      else
        query
      end

    query
    |> select([ec], ec.uuid)
    |> Repo.all()
  end

  def get_all_assigned_employee(user_id, q \\ nil) do
    employee = EmployeeCredential |> Repo.get_by(id: user_id, active: true)

    cond do
      EmployeeRole.super().id == employee.employee_role_id ->
        get_all_employee_by_role_id(EmployeeRole.dsa_super().id, q)

      true ->
        get_reporter_uuids(user_id, q)
    end
  end

  def get_reporter_ids_for_dsa(user_id) do
    dsa_roles = [EmployeeRole.dsa_admin().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_super().id]

    EmployeeCredential
    |> where([ec], ec.reporting_manager_id == ^user_id or ec.id == ^user_id)
    |> where([ec], ec.reporting_manager_id == ^user_id and ec.active == true and ec.employee_role_id in ^dsa_roles)
    |> select([ec], ec.id)
    |> Repo.all()
  end

  def get_all_employee_by_role_id(employee_role_id, q \\ nil) do
    query =
      EmployeeCredential
      |> where([ec], ec.employee_role_id == ^employee_role_id and ec.active == true)

    query =
      if(not is_nil(q) and String.trim(q) != "") do
        formatted_query = "%#{String.downcase(String.trim(q))}%"
        query |> where([ec], fragment("LOWER(?) LIKE ?", ec.name, ^formatted_query))
      else
        query
      end

    query
    |> select([ec], ec.uuid)
    |> Repo.all()
  end

  def get_manager_name_based_on_vertical(vertical_id) do
    case vertical_id do
      1 -> "Bn Manager"
      2 -> "Project Manager"
      3 -> "Owner Manager"
      4 -> "Commercial Manager"
      5 -> "Loan Manager"
      6 -> "Assisted Manager"
    end
  end

  def get_employee_by_uuids(user_id) do
    assigned_emp_uuids = get_all_assigned_employee(user_id)

    employess =
      EmployeeCredential
      |> where([ec], ec.uuid in ^assigned_emp_uuids and ec.active == true)
      |> select([ec], %{
        id: ec.id,
        name: ec.name,
        phone_number: ec.phone_number,
        employee_role_id: ec.employee_role_id,
        uuid: ec.uuid
      })
      |> Repo.all()

    {:ok, employess}
  end

  def check_for_user_reportees(user_id) do
    dsa_roles = [EmployeeRole.dsa_admin().id, EmployeeRole.dsa_agent().id, EmployeeRole.dsa_super().id]

    reportee_count =
      EmployeeCredential
      |> where([e], e.reporting_manager_id == ^user_id and e.active == true and e.employee_role_id in ^dsa_roles)
      |> Repo.aggregate(:count, :id)

    if(reportee_count > 0) do
      {true, reportee_count}
    else
      {false, nil}
    end
  end

  def get_all_assigned_employee_for_an_employee(user_id, emp_list \\ [], level_count \\ 0) do
    {has_reportees, _count} = check_for_user_reportees(user_id)

    if(not has_reportees) do
      emp_list ++ [user_id]
    else
      employee_ids = EmployeeCredential.get_reporter_ids_for_dsa(user_id)

      employee_ids
      |> Enum.reduce([], fn id, acc ->
        acc ++ get_all_assigned_employee_for_an_employee(id, emp_list ++ employee_ids, level_count + 1)
      end)
    end
  end
end
