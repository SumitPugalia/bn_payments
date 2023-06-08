defmodule BnApis.CallLogs.CallLog do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.CallLogs
  alias BnApis.CallLogs.CallLog
  alias BnApis.Contacts.BrokerUniverse
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.{Broker, Organization}
  alias BnApis.Helpers.FormHelper
  alias BnApis.Feedbacks.FeedbackSession

  schema "call_logs" do
    field :uuid, Ecto.UUID, read_after_writes: true
    field :call_duration, :integer
    # Frontend Generate UUID
    field :call_log_uuid, Ecto.UUID
    field :phone_number, :string
    field :country_code, :string, default: "+91"
    field :sim_id, :string
    field :end_time, :naive_datetime
    field :start_time, :naive_datetime
    field :call_status_id, :id
    field :user_id, :id
    field :is_professional, :boolean

    belongs_to :feedback_session, FeedbackSession
    belongs_to :call_log, CallLog
    timestamps()
  end

  @required [:phone_number, :country_code, :call_log_uuid, :user_id, :call_status_id]
  @fields @required ++
            [:is_professional, :feedback_session_id, :start_time, :end_time, :call_duration, :sim_id, :call_log_id]

  @doc false
  def changeset(call_log, attrs) do
    call_log
    |> cast(attrs, @fields)
    |> validate_required(@required)
    |> foreign_key_constraint(:call_status_id)
    |> foreign_key_constraint(:call_log_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:feedback_session_id)
    |> unique_constraint(:call_log_uuid, name: :call_log_uuid_index, message: "Client call log uuid already present!")
    |> unique_constraint(:user_id, name: :log_pair_constraint, message: "User with this call log already present!")
    |> FormHelper.validate_phone_number(:phone_number)
  end

  @doc """
  Removes archived stories.
  """
  def all_call_logs_query(user_id) do
    CallLog
    |> where([cl], cl.user_id == ^user_id and cl.is_professional == true)
    |> order_by(desc: :inserted_at)
  end

  def call_logs_with_broker_query(user_id, broker_number) do
    CallLog
    |> where([cl], cl.user_id == ^user_id and cl.phone_number == ^broker_number and cl.is_professional == true)
    |> order_by(desc: :inserted_at)
    |> limit(3)
  end

  def add_limit(query, page) do
    per_page = CallLogs.logs_per_page()

    query
    |> limit(^per_page)
    |> offset(^((page - 1) * per_page))
  end

  def get_count(query) do
    query
    |> BnApis.Repo.aggregate(:count, :id)
  end

  def select_query(query) do
    query
    |> join(:inner, [cl], cred in Credential, on: cred.phone_number == cl.phone_number and cred.active == true)
    |> join(:left, [cl, cred], bu in BrokerUniverse, on: bu.phone_number == cl.phone_number)
    |> join(:inner, [cl, cred, bu], b in Broker, on: b.id == cred.broker_id)
    |> join(:inner, [cl, cred, bu, b], o in Organization, on: o.id == cred.organization_id)
    |> select([call_log, c, bu, b, o], %{
      inserted_at: call_log.inserted_at,
      phone_number: call_log.phone_number,
      call_log_uuid: call_log.call_log_uuid,
      uuid: call_log.uuid,
      start_time: call_log.start_time,
      call_duration: call_log.call_duration,
      call_status_id: call_log.call_status_id,
      sim_id: call_log.sim_id,
      type: "normal",
      contact_details: %{
        uuid: c.uuid,
        profile_pic_url: b.profile_image,
        phone_number: c.phone_number,
        org_name: o.name,
        name: b.name
      },
      contact_details_from_universe: %{
        uuid: bu.uuid,
        profile_pic_url: nil,
        phone_number: bu.phone_number,
        org_name: bu.organization_name,
        name: bu.name
      }
    })
  end

  def call_log_query(log_id) do
    CallLog |> where(id: ^log_id) |> select_query
  end
end
