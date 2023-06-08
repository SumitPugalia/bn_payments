defmodule BnApis.Organizations.BillingCompany do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BnApis.Helpers.AuditedRepo
  alias BnApis.Repo
  alias BnApis.Accounts.{Credential, EmployeeRole, EmployeeCredential}
  alias BnApis.Organizations.{BillingCompany, BankAccount, Broker, BrokerRole}
  alias BnApis.Organizations.Organization
  alias BnApis.Helpers.{S3Helper, ApplicationHelper, Time}
  alias BnApis.AssignedBrokers

  schema "billing_companies" do
    field(:uuid, Ecto.UUID, read_after_writes: true)
    field(:name, :string)
    field(:address, :string)
    field(:place_of_supply, :string)

    # String Enum -> ["One Person Company", "Sole Proprietorship", "Private Limited Company", "Public Limited Company", "Joint-Venture Company", "Partnership Firm"]
    field(:company_type, :string)
    field(:email, :string)
    field(:gst, :string)
    field(:pan, :string)
    field(:rera_id, :string)
    field(:signature, :string)
    field(:bill_to_state, :string)
    field(:bill_to_pincode, :integer)
    field(:bill_to_city, :string)
    field(:active, :boolean, default: true)
    field(:status, Ecto.Enum, values: [:draft, :approval_pending, :changes_requested, :approved, :rejected, :deleted])
    field(:change_notes, :string)
    field(:razorpay_fund_account_id, :string)

    belongs_to(:broker, Broker)
    belongs_to(:old_broker, Broker)
    belongs_to(:old_organization, Organization)

    has_one(:bank_account, BankAccount,
      foreign_key: :billing_company_id,
      on_delete: :delete_all,
      on_replace: :delete
    )

    timestamps()
  end

  @fields [
    :uuid,
    :name,
    :address,
    :place_of_supply,
    :company_type,
    :email,
    :gst,
    :pan,
    :rera_id,
    :signature,
    :bill_to_state,
    :bill_to_pincode,
    :bill_to_city,
    :broker_id,
    :active,
    :status,
    :change_notes,
    :old_broker_id,
    :old_organization_id,
    :razorpay_fund_account_id
  ]

  @valid_company_types [
    "One Person Company",
    "Sole Proprietorship",
    "Private Limited Company",
    "Public Limited Company",
    "Joint-Venture Company",
    "Partnership Firm",
    "Limited Liability Partnership"
  ]

  @valid_status_change %{
    nil => [:draft, :approval_pending, :approved, :deleted],
    :draft => [:approval_pending, :deleted],
    :approval_pending => [:changes_requested, :approved, :rejected, :deleted],
    :changes_requested => [:approval_pending, :approved, :rejected, :deleted],
    :approved => [],
    :rejected => [:deleted, :approval_pending],
    :deleted => []
  }

  @draft_status_text "Draft"
  @approval_pending_status_text "Approval Pending"
  @changes_requested_status_text "Changes Requested"
  @approved_status_text "Approved"
  @rejected_status_text "Rejected"
  @deleted_status_text "Deleted"

  @gst_code_to_place_of_supply %{
    1 => %{name: "JAMMU AND KASHMIR", gst: 01},
    2 => %{name: "HIMACHAL PRADESH", gst: 02},
    3 => %{name: "PUNJAB", gst: 03},
    4 => %{name: "CHANDIGARH", gst: 04},
    5 => %{name: "UTTARAKHAND", gst: 05},
    6 => %{name: "HARYANA", gst: 06},
    7 => %{name: "DELHI", gst: 07},
    8 => %{name: "RAJASTHAN", gst: 08},
    9 => %{name: "UTTAR PRADESH", gst: 09},
    10 => %{name: "BIHAR", gst: 10},
    11 => %{name: "SIKKIM", gst: 11},
    12 => %{name: "ARUNACHAL PRADESH", gst: 12},
    13 => %{name: "NAGALAND", gst: 13},
    14 => %{name: "MANIPUR", gst: 14},
    15 => %{name: "MIZORAM", gst: 15},
    16 => %{name: "TRIPURA", gst: 16},
    17 => %{name: "MEGHALAYA", gst: 17},
    18 => %{name: "ASSAM", gst: 18},
    19 => %{name: "WEST BENGAL", gst: 19},
    20 => %{name: "JHARKHAND", gst: 20},
    21 => %{name: "ODISHA", gst: 21},
    22 => %{name: "CHATTISGARH", gst: 22},
    23 => %{name: "MADHYA PRADESH", gst: 23},
    24 => %{name: "GUJARAT", gst: 24},
    26 => %{name: "DADRA AND NAGAR HAVELI AND DAMAN AND DIU", gst: 26},
    27 => %{name: "MAHARASHTRA", gst: 27},
    28 => %{name: "ANDHRA PRADESH (BEFORE DIVISION)", gst: 28},
    29 => %{name: "KARNATAKA", gst: 29},
    30 => %{name: "GOA", gst: 30},
    31 => %{name: "LAKSHADWEEP", gst: 31},
    32 => %{name: "KERALA", gst: 32},
    33 => %{name: "TAMIL NADU", gst: 33},
    34 => %{name: "PUDUCHERRY", gst: 34},
    35 => %{name: "ANDAMAN AND NICOBAR ISLANDS", gst: 35},
    36 => %{name: "TELANGANA", gst: 36},
    37 => %{name: "ANDHRA PRADESH (NEWLY ADDED)", gst: 37}
  }

  @imgix_domain ApplicationHelper.get_imgix_domain()

  @required_fields [
    :name,
    :address,
    :place_of_supply,
    :company_type,
    :pan,
    :bill_to_state,
    :bill_to_pincode,
    :bill_to_city,
    :broker_id,
    :status,
    :signature,
    :old_broker_id,
    :old_organization_id
  ]

  def changeset(billing_company, attrs \\ %{}) do
    old_status = Map.get(billing_company, :status)

    billing_company
    |> cast(attrs, @fields)
    |> validate_required(@required_fields)
    |> validate_status_change(old_status)
    |> validate_company_type()
    |> validate_place_of_supply()
    |> validate_change(:pan, &validate_pan/2)
    |> validate_gst()
    |> validate_format(:email, ~r/@/, message: "Invalid Email format.")
    |> foreign_key_constraint(:broker_id)
    |> format_changeset_response()
  end

  @doc """
    Lists all the billing companies.
  """
  def all_billing_companies(params, employee_role_id, user_id) do
    page_no = Map.get(params, "p", "1") |> String.to_integer() |> max(1)
    limit = Map.get(params, "limit", "30") |> String.to_integer() |> max(1) |> min(100)
    status = Map.get(params, "status") |> parse_string()
    broker_phone_number = Map.get(params, "broker_phone_number") |> parse_string()
    broker_name = Map.get(params, "broker_name") |> parse_string()
    role_type_id = Map.get(params, "role_type_id")
    role_type_id = if is_binary(role_type_id), do: String.to_integer(role_type_id), else: role_type_id
    billing_company_name = Map.get(params, "billing_company_name") |> parse_string()

    get_paginated_results(page_no, limit, status, broker_phone_number, broker_name, role_type_id, billing_company_name, employee_role_id, user_id)
  end

  @doc """
    Lists billing companies for the logged in broker.
  """
  def get_billing_companies_for_broker(session_data, show_rera_billing_companies_only \\ true) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    credential_id = Map.get(session_data, "user_id")
    query = query_with_rera_check(show_rera_billing_companies_only)

    billing_companies =
      query
      |> preload([:bank_account])
      |> where(^filter_by_org_acccess(broker_id, credential_id, get_in(session_data, ["profile", "broker_role_id"])))
      |> where([bc], bc.active == true)
      |> distinct(true)
      |> order_by(desc: :id)
      |> Repo.all()

    billing_companies
    |> Enum.map(fn billing_company ->
      billing_company_map = create_billing_company_map(billing_company)
      bank_account_map = BankAccount.create_bank_account_map(billing_company.bank_account)
      Map.put(billing_company_map, :bank_account, bank_account_map)
    end)
  end

  @doc """
   Retrieve a billing company based on a uuid.
  """
  def fetch_billing_company(uuid) do
    billing_company = get_billing_company_from_repo(uuid)

    if not is_nil(billing_company) do
      billing_company_map = create_billing_company_map(billing_company)
      bank_account_map = BankAccount.create_bank_account_map(billing_company.bank_account)

      Map.put(billing_company_map, :bank_account, bank_account_map)
    end
  end

  @doc """
    Updates a billing company based on uuid.
  """
  def update_billing_company(
        params = %{
          "uuid" => uuid,
          "name" => name,
          "address" => address,
          "place_of_supply" => place_of_supply,
          "company_type" => company_type,
          "pan" => pan,
          "bill_to_state" => bill_to_state,
          "bill_to_pincode" => bill_to_pincode,
          "bill_to_city" => bill_to_city,
          "active" => active
        },
        broker_id
      ) do
    rera_id = Map.get(params, "rera_id") |> parse_string()
    email = Map.get(params, "email")
    gst = Map.get(params, "gst") |> parse_string()
    signature = Map.get(params, "signature")
    bank_account = Map.get(params, "bank_account")
    status = parse_status(broker_id)

    place_of_supply = String.trim(place_of_supply)
    company_type = String.trim(company_type)
    pan = String.trim(pan)

    billing_company = get_billing_company_from_repo(uuid)

    cond do
      is_nil(billing_company) ->
        {:error, "Billing Company not found"}

      billing_company ->
        billing_company
        |> changeset(%{
          uuid: uuid,
          name: name,
          address: address,
          place_of_supply: place_of_supply,
          company_type: company_type,
          email: email,
          gst: gst,
          pan: pan,
          rera_id: rera_id,
          signature: signature,
          bill_to_state: bill_to_state,
          bill_to_pincode: bill_to_pincode,
          bill_to_city: bill_to_city,
          broker_id: broker_id,
          active: active,
          status: status
        })
        |> case do
          {:error, changeset} ->
            {:error, changeset}

          {:ok, changeset} ->
            case BankAccount.update_bank_account(bank_account, billing_company.id) do
              {:ok, _bank_account} ->
                Repo.update(changeset)

              {:error, error} ->
                {:error, error}
            end
        end
    end
  end

  def update_billing_company(_params, _broker_id), do: {:error, "Invalid billing company params."}

  def maybe_create_billing_company(
        params = %{
          "name" => _name,
          "address" => _address,
          "place_of_supply" => _place_of_supply,
          "company_type" => _company_type,
          "pan" => _pan,
          "bill_to_state" => _bill_to_state,
          "bill_to_pincode" => _bill_to_pincode,
          "bill_to_city" => _bill_to_city
        },
        broker_id,
        broker_role_id,
        organization_id
      ) do
    broker = Broker.fetch_broker_from_id(broker_id)

    with {true, []} <- has_conflicts(params, broker_id, broker.role_type_id, organization_id),
         {:ok, billing_company} <- create(params, broker_id, broker_role_id) do
      {:ok, billing_company}
    else
      {false, []} ->
        {:error, "A billing company with same details was already created by your user."}

      {false, conflicts} ->
        {:ok, conflicts}

      {:error, error} ->
        {:error, error}
    end
  end

  def maybe_create_billing_company(_params, _broker_id, _broker_role_id, _organization_id), do: {:error, "Invalid billing company params."}

  @doc """
    Creates a billing company based on provided params.
  """
  def create(
        params = %{
          "name" => name,
          "address" => address,
          "place_of_supply" => place_of_supply,
          "company_type" => company_type,
          "pan" => pan,
          "bill_to_state" => bill_to_state,
          "bill_to_pincode" => bill_to_pincode,
          "bill_to_city" => bill_to_city
        },
        broker_id,
        broker_role_id
      ) do
    rera_id = Map.get(params, "rera_id") |> parse_string()
    email = Map.get(params, "email")
    gst = Map.get(params, "gst") |> parse_string()
    signature = Map.get(params, "signature")
    bank_account = Map.get(params, "bank_account")
    status = parse_status(broker_id)

    place_of_supply = String.trim(place_of_supply)
    company_type = String.trim(company_type)
    pan = String.trim(pan)
    cred = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload([:organization])

    billing_company_changes = %{
      name: name,
      address: address,
      place_of_supply: place_of_supply,
      company_type: company_type,
      email: email,
      gst: gst,
      pan: pan,
      rera_id: rera_id,
      signature: signature,
      bill_to_state: bill_to_state,
      bill_to_pincode: bill_to_pincode,
      bill_to_city: bill_to_city,
      broker_id: broker_id,
      active: true,
      status: status,
      old_broker_id: broker_id,
      old_organization_id: cred.organization.id
    }

    Repo.transaction(fn ->
      with {:valid, true} <- {:valid, BrokerRole.admin().id == broker_role_id or cred.organization.members_can_add_billing_company},
           {:ok, bc_changeset} <- changeset(%BillingCompany{}, billing_company_changes),
           {:ok, billing_company} <- Repo.insert(bc_changeset),
           {:ok, bank_account_map} <- BankAccount.add_bank_account_for_company(billing_company.id, bank_account) do
        billing_company
        |> create_billing_company_map()
        |> Map.put(:bank_account, bank_account_map)
      else
        {:valid, false} -> Repo.rollback("Your comapny admin had disabled this feature")
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def create(_params, _broker_id, _broker_role_id), do: {:error, "Invalid billing company params."}

  @doc """
    Delete a billing company based on uuid.
  """
  def delete_billing_company(uuid, broker_id) do
    get_billing_company_by_uuid(uuid, broker_id)
    |> case do
      nil -> {:error, :not_found}
      billing_company -> deactivate_billing_company(billing_company)
    end
  end

  @doc """
    Panel API: Approve a billing company
  """
  def mark_as_approved(uuid, user_map) do
    with %BillingCompany{} = billing_company <- get_billing_company_from_repo(uuid),
         {:cred, credential} when not is_nil(credential) <- {:cred, Credential.get_credential_from_broker_id(billing_company.broker_id)},
         {:razorpay , {:ok, fund_id}} <- {:razorpay, BnApis.Accounts.update_bank_acount_into_razorpay(billing_company.bank_account, credential)} do
      billing_company
      |> changeset(%{status: :approved, razorpay_fund_account_id: fund_id})
      |> case do
        {:ok, changeset} -> AuditedRepo.update(changeset, user_map)
        {:error, error} -> {:error, error}
      end
    else
      nil -> {:error, :not_found}
      {:cred, nil} -> {:error, "credentials not found"}
      {:razorpay , {:error, error_desc}} -> {:error, error_desc}
      error -> error
    end
  end

  @doc """
    Panel API: Reject a billing company
  """
  def mark_as_rejected(uuid, change_notes) do
    billing_company = get_billing_company_from_repo(uuid)

    cond do
      is_nil(billing_company) ->
        {:error, :not_found}

      billing_company ->
        billing_company
        |> changeset(%{status: :rejected, change_notes: change_notes})
        |> case do
          {:ok, changeset} -> Repo.update(changeset)
          {:error, error} -> {:error, error}
        end
    end
  end

  def move_to_pending(uuid) do
    billing_company = get_billing_company_from_repo(uuid)

    cond do
      is_nil(billing_company) ->
        {:error, :not_found}

      billing_company ->
        billing_company
        |> changeset(%{status: :approval_pending})
        |> case do
          {:ok, changeset} -> Repo.update(changeset)
          {:error, error} -> {:error, error}
        end
    end
  end

  @doc """
    Panel API: Request changes for a billing company
  """
  def request_changes(uuid, change_notes) do
    billing_company = get_billing_company_from_repo(uuid)

    cond do
      is_nil(billing_company) ->
        {:error, :not_found}

      billing_company ->
        billing_company
        |> changeset(%{status: :changes_requested, change_notes: change_notes})
        |> case do
          {:ok, changeset} -> Repo.update(changeset)
          {:error, error} -> {:error, error}
        end
    end
  end

  def get_billing_company_from_repo_by_pan(pan) do
    BillingCompany
    |> where([bc], fragment("lower(?) = lower(?)", bc.pan, ^pan))
    |> limit(1)
    |> Repo.one()
  end

  @doc """
    Meta api -  Returns a list of valid place of supply
  """
  def get_valid_place_of_supply() do
    @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.name end) |> Enum.sort()
  end

  @doc """
    Meta Data api -  Returns a list of valid billing company types
  """
  def get_billing_company_types() do
    @valid_company_types
  end

  ## Private APIs

  defp query_with_rera_check(true), do: BillingCompany |> where([bc], not is_nil(bc.rera_id))
  defp query_with_rera_check(false), do: BillingCompany

  defp fetch_org_admin_brokers(nil), do: []

  defp fetch_org_admin_brokers(credential_id) do
    credential = Credential |> Repo.get_by(id: credential_id)

    Credential
    |> where([cred], cred.id != ^credential_id and cred.active == true)
    |> where([cred], cred.broker_role_id == ^BrokerRole.admin().id and cred.organization_id == ^credential.organization_id)
    |> select([cred], cred.broker_id)
    |> distinct(true)
    |> Repo.all()
  end

  defp format_changeset_response(%Ecto.Changeset{valid?: true} = changeset), do: {:ok, changeset}

  defp format_changeset_response(changeset), do: {:error, changeset}

  defp parse_string(nil), do: nil
  defp parse_string(string), do: String.trim(string)

  defp validate_company_type(changeset) do
    company_type = get_field(changeset, :company_type)

    if not is_nil(company_type) and Enum.member?(@valid_company_types, company_type) do
      changeset
    else
      add_error(changeset, :company_type, "Company Type is not valid.")
    end
  end

  defp validate_place_of_supply(changeset) do
    place_of_supply = get_field(changeset, :place_of_supply)
    valid_place_of_supply = @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.name end)

    if not is_nil(place_of_supply) and Enum.member?(valid_place_of_supply, String.upcase(place_of_supply)) do
      changeset
    else
      add_error(changeset, :place_of_supply, "Place of supply is not valid.")
    end
  end

  defp validate_pan(:pan, pan) do
    invalid_pan_length? = not (String.length(pan) == 10)
    invalid_pan_pattern? = not String.match?(pan, ~r/[A-Z]{5}[0-9]{4}[A-Z]{1}/i)

    case {invalid_pan_length?, invalid_pan_pattern?} do
      {true, _} ->
        [pan: "PAN is of an invalid length."]

      {_, true} ->
        [pan: "PAN is invalid."]

      {_, _} ->
        []
    end
  end

  defp validate_gst(changeset) do
    gst = get_field(changeset, :gst)
    gst_length = if not is_nil(gst), do: String.length(gst), else: 0

    if not is_nil(gst) and gst_length == 15 do
      valid_gst_codes = @gst_code_to_place_of_supply |> Map.values() |> Enum.map(fn id -> id.gst end)

      valid_gst_code? =
        if String.match?(String.slice(gst, 0, 2), ~r/^[[:digit:]]+$/) do
          gst_code = String.to_integer(String.slice(gst, 0, 2), 10)
          if Enum.member?(valid_gst_codes, gst_code), do: true, else: false
        else
          false
        end

      valid_pan? =
        if String.downcase(String.slice(gst, 2, 10)) == String.downcase(get_field(changeset, :pan)),
          do: true,
          else: false

      valid_end_gst? = String.match?(String.slice(gst, 12, 3), ~r/[A-Z0-9]{3}/i)

      if valid_gst_code? and valid_pan? and valid_end_gst? do
        changeset
      else
        add_error(changeset, :gst, "GST is invalid.")
      end
    else
      if is_nil(gst), do: changeset, else: add_error(changeset, :gst, "GST is of an invalid length.")
    end
  end

  defp get_billing_company_from_repo(uuid, preload \\ []) do
    BillingCompany
    |> Repo.get_by(uuid: uuid)
    |> case do
      nil -> nil
      struct -> Repo.preload(struct, [:bank_account] ++ preload)
    end
  end

  defp get_paginated_results(page_no, limit, status, broker_phone_number, broker_name, role_type_id, billing_company_name, employee_role_id, user_id) do
    offset = (page_no - 1) * limit

    query =
      get_status_query(status)
      |> filter_by_dsa_hierarchy(employee_role_id, user_id)
      |> filter_by_broker_phone_number(broker_phone_number)
      |> filter_by_broker_name(broker_name)
      |> filter_by_role_type_id(role_type_id)
      |> filter_by_billing_company_name(billing_company_name)

    billing_companies =
      query
      |> preload([:bank_account])
      |> order_by(desc: :updated_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    billing_companies_map =
      billing_companies
      |> Enum.map(fn billing_company ->
        billing_company_map = create_billing_company_map(billing_company)
        bank_account_map = BankAccount.create_bank_account_map(billing_company.bank_account)

        Map.put(billing_company_map, :bank_account, bank_account_map)
      end)

    %{
      "billing_companies" => billing_companies_map,
      "next_page_exists" => Enum.count(billing_companies) >= limit,
      "next_page_query_params" => "p=#{page_no + 1}"
    }
  end

  defp parse_signature(nil), do: nil

  defp parse_signature(signature) do
    String.contains?(signature, @imgix_domain)
    |> case do
      true ->
        signature

      false ->
        S3Helper.get_imgix_url(signature)
    end
  end

  def create_billing_company_map(nil), do: nil

  def create_billing_company_map(billing_company) do
    billing_company = billing_company |> Repo.preload([:broker])
    broker_map = Broker.create_broker_map(billing_company.broker)

    %{
      "uuid" => billing_company.uuid,
      "id" => billing_company.id,
      "name" => billing_company.name,
      "address" => billing_company.address,
      "place_of_supply" => billing_company.place_of_supply,
      "company_type" => billing_company.company_type,
      "email" => billing_company.email,
      "gst" => billing_company.gst,
      "pan" => billing_company.pan,
      "rera_id" => billing_company.rera_id,
      "signature" => parse_signature(billing_company.signature),
      "bill_to_state" => billing_company.bill_to_state,
      "bill_to_pincode" => billing_company.bill_to_pincode,
      "bill_to_city" => billing_company.bill_to_city,
      "broker_id" => billing_company.broker_id,
      "active" => billing_company.active,
      "status" => billing_company.status,
      "status_display_text" => get_display_text(billing_company.status),
      "enable_edit" => enable_edit(billing_company.status),
      "enable_delete" => enable_delete(billing_company.status),
      "change_notes" => billing_company.change_notes,
      "broker" => broker_map,
      "inserted_at" => Time.naive_to_epoch_in_sec(billing_company.inserted_at)
    }
  end

  def deactivate_brokers_billing_companies(broker_id) do
    BillingCompany
    |> where([bc], bc.broker_id == ^broker_id and bc.active == true)
    |> Repo.all()
    |> Enum.each(fn bc -> deactivate_billing_company(bc) end)
  end

  def deactivate_billing_company(billing_company) do
    case billing_company |> changeset(%{active: false, status: :deleted}) do
      {:ok, changeset} -> Repo.update(changeset)
      {:error, error} -> {:error, error}
    end
  end

  defp parse_status(broker_id) do
    broker = Broker |> Repo.get_by(id: broker_id)

    case broker do
      nil ->
        :approval_pending

      broker ->
        if broker.role_type_id == Broker.dsa()["id"], do: :approval_pending, else: :approved
    end
  end

  defp enable_edit(nil), do: true
  defp enable_edit(status) when status in [:draft, :approval_pending, :changes_requested], do: true
  defp enable_edit(_), do: false

  defp enable_delete(:approved), do: false
  defp enable_delete(_), do: true

  defp get_display_text(nil), do: ""
  defp get_display_text(:draft), do: @draft_status_text
  defp get_display_text(:approval_pending), do: @approval_pending_status_text
  defp get_display_text(:changes_requested), do: @changes_requested_status_text
  defp get_display_text(:approved), do: @approved_status_text
  defp get_display_text(:rejected), do: @rejected_status_text
  defp get_display_text(:deleted), do: @deleted_status_text
  defp get_display_text(_), do: "Invalid Status"

  defp validate_status_change(changeset = %{valid?: true}, old_status) do
    new_status = get_field(changeset, :status)

    if valid_status_change(old_status, new_status),
      do: changeset,
      else: add_error(changeset, :status, "Cannot change status from #{old_status} to #{new_status}")
  end

  defp validate_status_change(changeset, _old_status), do: changeset

  defp valid_status_change(status, status) when not is_nil(status), do: true
  defp valid_status_change(old_status, new_status), do: @valid_status_change[old_status] |> Enum.any?(&(&1 == new_status))

  defp get_billing_company_by_uuid(nil, _broker_id), do: nil

  defp get_billing_company_by_uuid(uuid, broker_id) do
    BillingCompany
    |> where([bc], bc.broker_id == ^broker_id and bc.uuid == ^uuid)
    |> Repo.one()
  end

  defp get_status_query(nil), do: BillingCompany |> where([bc], bc.status not in [:draft, :deleted] or is_nil(bc.status))
  defp get_status_query(""), do: BillingCompany |> where([bc], bc.status not in [:draft, :deleted] or is_nil(bc.status))
  defp get_status_query(status), do: BillingCompany |> where([bc], bc.status not in [:draft, :deleted] and ilike(bc.status, ^status))

  defp filter_by_broker_phone_number(query, ""), do: query

  defp filter_by_broker_phone_number(query, phone_number) when is_binary(phone_number) do
    phone_number = "%" <> phone_number <> "%"

    query
    |> join(:left, [bc], br in assoc(bc, :broker))
    |> join(:left, [bc, br], cred in assoc(br, :credentials))
    |> where([bc, br, cred], like(cred.phone_number, ^phone_number))
  end

  defp filter_by_broker_phone_number(query, _phone_number), do: query

  defp filter_by_broker_name(query, ""), do: query

  defp filter_by_broker_name(query, broker_name) when is_binary(broker_name) do
    broker_name = "%" <> broker_name <> "%"

    query
    |> join(:left, [bc], br in assoc(bc, :broker))
    |> where([bc, br], ilike(br.name, ^broker_name))
  end

  defp filter_by_broker_name(query, _broker_name), do: query

  defp filter_by_billing_company_name(query, ""), do: query

  defp filter_by_billing_company_name(query, billing_company_name) when is_binary(billing_company_name) do
    billing_company_name = "%" <> billing_company_name <> "%"

    query
    |> where([bc], ilike(bc.name, ^billing_company_name))
  end

  defp filter_by_billing_company_name(query, _broker_name), do: query

  defp filter_by_org_acccess(broker_id, credential_id, role_id) do
    org_admin_brokers = fetch_org_admin_brokers(credential_id)
    cred = Repo.get_by(Credential, id: credential_id) |> Repo.preload([:organization])

    if BrokerRole.admin().id == role_id or cred.organization.members_can_add_billing_company do
      dynamic([bc], bc.broker_id == ^broker_id or bc.broker_id in ^org_admin_brokers)
    else
      dynamic([bc], bc.broker_id in ^org_admin_brokers)
    end
  end

  def get_change_requested_billing_company_count(broker_id) do
    BillingCompany
    |> where([bc], bc.broker_id == ^broker_id and bc.status == :changes_requested)
    |> Repo.aggregate(:count, :id)
  end

  defp filter_by_role_type_id(query, nil), do: query

  defp filter_by_role_type_id(query, role_type_id) do
    query
    |> join(:left, [bc], br in assoc(bc, :broker))
    |> where([bc, br], br.role_type_id == ^role_type_id)
  end

  defp filter_by_dsa_hierarchy(query, employee_role_id, user_id) do
    cond do
      employee_role_id in [EmployeeRole.dsa_super().id, EmployeeRole.dsa_admin().id, EmployeeRole.dsa_agent().id] ->
        dsa_agent_ids = EmployeeCredential.get_all_assigned_employee_for_an_employee(user_id)

        query
        |> join(:inner, [bc], br in assoc(bc, :broker))
        |> join(:inner, [bc, br], cred in assoc(br, :credentials))
        |> join(:inner, [bc, br, cred], ab in AssignedBrokers, on: cred.broker_id == ab.broker_id)
        |> where([bc, br, cred, ab], ab.employees_credentials_id in ^dsa_agent_ids)

      true ->
        query
    end
  end

  defp has_conflicts(params, broker_id, broker_role_type_id, organization_id) do
    if broker_role_type_id == Broker.dsa()["id"] do
      {true, []}
    else
      pan = Map.get(params, "pan") |> parse_string()
      gst = Map.get(params, "gst") |> parse_string()
      rera_id = Map.get(params, "rera_id") |> parse_string()
      bank_account = Map.get(params, "bank_account")
      account_number = if not is_nil(bank_account), do: Map.get(bank_account, "account_number"), else: nil

      find_conflicting_broker_billing_companies(pan, gst, rera_id, account_number, organization_id, broker_id)
      |> case do
        conflicting_billing_companies when is_list(conflicting_billing_companies) and length(conflicting_billing_companies) > 0 ->
          conflicts =
            conflicting_billing_companies
            |> Enum.map(fn record ->
              org_admin_cred = Broker.fetch_org_admin_cred(record.org_id, broker_id)

              if not is_nil(org_admin_cred) do
                %{
                  "org_name" => record.org_name,
                  "org_address" => record.org_address,
                  "org_id" => record.org_id,
                  "billing_company_id" => record.billing_company_id,
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
  end

  defp find_conflicting_broker_billing_companies(pan, gst, rera_id, account_number, organization_id, broker_id) do
    filter_params = %{
      "pan" => pan,
      "gst" => gst,
      "rera_id" => rera_id,
      "account_number" => account_number
    }

    broker = Broker.fetch_broker_from_id(broker_id)

    BillingCompany
    |> join(:inner, [bc], ba in assoc(bc, :bank_account))
    |> join(:inner, [bc, ba], br in assoc(bc, :broker))
    |> join(:inner, [bc, ba, br], cred in assoc(br, :credentials))
    |> join(:inner, [bc, ba, br, cred], org in assoc(cred, :organization))
    |> where([bc, ba, br, cred, org], cred.active == true and bc.active == true and br.role_type_id == ^broker.role_type_id)
    |> where(^filter_billing_company_params(filter_params))
    |> filter_by_org_id(organization_id)
    |> distinct([bc, ba, br, cred, org], org.id)
    |> select([bc, ba, br, cred, org], %{
      org_id: org.id,
      org_name: org.name,
      org_address: org.firm_address,
      billing_company_id: bc.id
    })
    |> Repo.all()
  end

  defp filter_billing_company_params(filter) do
    Enum.reduce(filter, dynamic(false), fn
      {"pan", pan}, dynamic when is_binary(pan) ->
        dynamic([bc, ba, br, cred, org], ^dynamic or ilike(bc.pan, ^pan))

      {"gst", gst}, dynamic when is_binary(gst) ->
        dynamic([bc, ba, br, cred, org], ^dynamic or ilike(bc.gst, ^gst))

      {"rera_id", rera_id}, dynamic when is_binary(rera_id) ->
        dynamic([bc, ba, br, cred, org], ^dynamic or ilike(bc.rera_id, ^rera_id))

      {"account_number", account_number}, dynamic when is_binary(account_number) ->
        dynamic([bc, ba, br, cred, org], ^dynamic or ba.account_number == ^account_number)

      _, dynamic ->
        dynamic
    end)
  end

  defp parse_for_nil(nil, _key), do: nil
  defp parse_for_nil(record, key), do: Map.get(record, key)

  defp filter_by_org_id(query, nil), do: query

  defp filter_by_org_id(query, org_id) do
    query
    |> where([bc, ba, br, cred, org], org.id != ^org_id)
  end
end
