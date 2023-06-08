defmodule BnApis.Calls do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApisWeb.Helpers.PhoneHelper
  alias BnApis.Homeloan.Lead
  alias BnApis.Accounts.Credential
  alias BnApis.Calls
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Homeloan.HLCallLeadStatus

  schema "call_details" do
    field :tran_id, :string
    field :start_time, :string
    field :end_time, :string
    field :answer_time, :string
    field :customer_number, :string
    field :agent_number, :string
    field :duration, :string
    field :charge, :string
    field :unsuccessful_call_reason, :string
    field :recording_url, :string
    field :lead_id, :integer
    field :entity_type, :string
    field :call_with, :string
    field :call_type, :string

    timestamps()
  end

  @optional [
    :tran_id,
    :start_time,
    :end_time,
    :answer_time,
    :customer_number,
    :agent_number,
    :duration,
    :recording_url,
    :unsuccessful_call_reason,
    :charge,
    :recording_url,
    :lead_id,
    :call_with,
    :entity_type,
    :call_type
  ]

  # common agent phone numbers to be used while calling, access_number has been provided by s2c
  @homeloan_manager %{
    id: 1,
    name: "Home Loan Manager",
    access_number: ApplicationHelper.get_hl_manager_phone_number(),
    alternate_number: "xxxxxxxxxx"
  }

  @hl_lead "hl_lead"
  @broker "broker"
  @hl_agent "hl_agent"

  @doc false
  def changeset(call_details, attrs) do
    call_details
    |> cast(attrs, @optional)
  end

  def list_of_agents do
    [
      @homeloan_manager
    ]
  end

  def homeloan_manager do
    @homeloan_manager
  end

  def hl_lead do
    @hl_lead
  end

  def broker do
    @broker
  end

  def hl_agent do
    @hl_agent
  end

  def get_agent_type_by_phone_number(phone_number) do
    list_of_agents()
    |> Enum.filter(&(&1.access_number == phone_number))
    |> List.first()
    |> Map.get(:name)
  end

  def get_number_to_connect(params = %{"agent_type" => agent_type}) do
    hl_agent_name = @homeloan_manager.name

    cond do
      agent_type == hl_agent_name ->
        get_employee_number_using_client_number(params)

      true ->
        nil
    end
  end

  def get_employee_number_using_client_number(
        params = %{
          "client_number" => client_number
        }
      ) do
    # if the caller is a broker
    employee_number = get_broker_latest_lead_employee_number(client_number)

    # if the caller is a homeloan lead
    if is_nil(employee_number) do
      {employee_number, lead_id} = get_employee_number_by_hl_lead_phone_number(client_number)

      if not is_nil(lead_id) do
        save_initial_call_details_inbound(params, @hl_lead, employee_number, lead_id)
      end

      structure_get_employee_number_response(employee_number, params)
    else
      # in case the broker calls from phone directly, we will play an announcement which is shared to s2c by us.
      structure_voice_note_response(params["tran_id"])
    end
  end

  defp save_initial_call_details_inbound(params, call_with, agent_number, lead_id) do
    call_detail = Repo.get_by(Calls, tran_id: params["tran_id"])

    if is_nil(call_detail) do
      {:ok, result_ch} =
        Repo.insert(
          Calls.changeset(%Calls{}, %{
            tran_id: params["tran_id"],
            customer_number: params["client_number"],
            agent_number: agent_number,
            lead_id: lead_id,
            call_with: call_with,
            call_type: "inbound",
            entity_type: Lead.homeloan_schema_name()
          })
        )

      {:ok, _changeset} = HLCallLeadStatus.save_lead_status(result_ch.id, lead_id)
    else
      changeset =
        Calls.changeset(call_detail, %{
          customer_number: params["client_number"],
          agent_number: agent_number,
          lead_id: lead_id,
          call_with: call_with,
          call_type: "inbound",
          entity_type: Lead.homeloan_schema_name()
        })

      {:ok, result_ch} = Repo.update(changeset)
      {:ok, _changeset} = HLCallLeadStatus.save_lead_status(result_ch.id, lead_id)
    end
  end

  def structure_get_employee_number_response(employee_number, params) do
    resp = %{
      "dest_count" => 1,
      "digits_1" => PhoneHelper.append_country_code(employee_number, "91"),
      "name_1" => params["agent_type"],
      "msg_type" => "lookup.ack",
      "result" => 200,
      "reason" => "Success",
      "tran_id" => params["tran_id"],
      "sb_tag" => "",
      "cli_type" => "registered"
    }

    %{"reply" => resp}
  end

  def structure_voice_note_response(tran_id) do
    resp = %{
      "msg_type" => "lookup.nak",
      "result" => 614,
      "reason" => "Invalid Customer Number",
      "tran_id" => tran_id
    }

    %{"reply" => resp}
  end

  def get_broker_latest_lead_employee_number(client_number) do
    client_number = PhoneHelper.maybe_remove_country_code(client_number)
    cred = Credential.fetch_credential(client_number, "+91")

    case cred do
      nil ->
        nil

      cred ->
        latest_lead = Lead |> where([l], l.broker_id == ^cred.broker_id) |> order_by(desc: :inserted_at) |> limit(1) |> Repo.one()

        latest_lead = latest_lead |> Repo.preload(:employee_credentials)

        if not is_nil(latest_lead) and latest_lead.employee_credentials_id do
          latest_lead.employee_credentials.phone_number
        else
          nil
        end
    end
  end

  defp get_employee_number_by_hl_lead_phone_number(client_number) do
    client_number = PhoneHelper.maybe_remove_country_code(client_number)
    lead = Lead.get_homeloan_lead_by_phone(client_number) |> Repo.preload(:employee_credentials)

    case lead do
      nil ->
        {nil, nil}

      lead ->
        if !is_nil(lead.employee_credentials) do
          {lead.employee_credentials.phone_number, lead.id}
        else
          {nil, nil}
        end
    end
  end

  def save_call_details(params) do
    call_details = Repo.get_by(Calls, tran_id: params["tran_id"])

    if not is_nil(call_details) do
      changeset =
        Calls.changeset(call_details, %{
          start_time: params["start_time"],
          end_time: params["end_time"],
          answer_time: params["answer_time"],
          duration: params["duration"],
          charge: params["charge"],
          unsuccessful_call_reason: params["reason"],
          recording_url: params["recording_url"]
        })

      Repo.update(changeset)
    else
      changeset =
        Calls.changeset(%Calls{}, %{
          tran_id: params["tran_id"],
          start_time: params["start_time"],
          end_time: params["end_time"],
          customer_number: params["customer_number"],
          agent_number: params["agent_number"],
          answer_time: params["answer_time"],
          duration: params["duration"],
          charge: params["charge"],
          unsuccessful_call_reason: params["reason"],
          recording_url: params["recording_url"]
        })

      Repo.insert(changeset)
    end
  end

  def connect_call_to_client(params) do
    save_initial_call_details_outbound(params)
    s2c_params = Map.drop(params, [:call_with, :lead_id])

    result =
      s2c_params
      |> add_get_client_access_number_params()
      |> MapToXml.from_map()
      |> ExternalApiHelper.s2c_outbound_call()

    result =
      if not is_nil(result) do
        access_number = PhoneHelper.structure_12_digit_number(ApplicationHelper.get_hl_manager_phone_number())
        %{"message" => "You will receive a call from #{access_number} shortly"}
      else
        %{"message" => "Not able to make the call at a moment"}
      end

    {:ok, result}
  end

  def save_initial_call_details_outbound(params) do
    case params["call_with"] do
      @hl_agent ->
        changeset =
          Calls.changeset(%Calls{}, %{
            tran_id: params["tran_id"],
            # in case when broker tries outbound,  broker would be considered as agent
            customer_number: params["agent_number"],
            agent_number: params["customer_number"],
            lead_id: params["lead_id"],
            call_with: "broker",
            call_type: params["call_type"],
            entity_type: Lead.homeloan_schema_name()
          })

        result_ch = Repo.insert!(changeset)
        HLCallLeadStatus.save_lead_status(result_ch.id, params["lead_id"])

      _ ->
        changeset =
          Calls.changeset(%Calls{}, %{
            tran_id: params["tran_id"],
            customer_number: params["customer_number"],
            agent_number: params["agent_number"],
            lead_id: params["lead_id"],
            call_with: params["call_with"],
            call_type: params["call_type"],
            entity_type: Lead.homeloan_schema_name()
          })

        {:ok, result_ch} = Repo.insert(changeset)
        HLCallLeadStatus.save_lead_status(result_ch.id, params["lead_id"])
    end
  end

  defp add_get_client_access_number_params(params) do
    params =
      Map.merge(params, %{
        "msg_type" => "dial_out",
        "un" => Application.get_env(:bn_apis, :bn_username_in_s2c),
        "pw" => Application.get_env(:bn_apis, :bn_pwd_in_s2c),
        "svr" => "conference.simple2call.in",
        "routed_name" => Application.get_env(:bn_apis, :routed_name),
        "sb_tag" => ""
      })

    %{"request" => params}
  end

  def create_response_for_outbound_notify(params) do
    %{
      "reply" => %{
        "msg_type" => "outbound_notify.ack",
        "result" => 200,
        "reason" => "Success",
        "tran_id" => params["tran_id"]
      }
    }
  end
end
