defmodule BnApis.Rewards.RewardsLead do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Rewards.Status
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Stories.Story
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Organizations.{Broker, BrokerLevel}
  alias BnApis.Accounts.Credential
  alias BnApis.Rewards.Payout
  alias BnApis.Rewards.EmployeePayout
  alias BnApis.Rewards.FailureReason
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Rewards.StoryTier
  alias BnApis.Posts.ConfigurationType
  alias BnApis.AssignedBrokers
  alias BnApis.Helpers.Time

  @processed_status "processed"
  # @create_lead_whatsapp_template "builder_1"

  schema "rewards_leads" do
    field(:name, :string)
    field(:visit_date, :naive_datetime)
    field(:release_employee_payout, :boolean)
    belongs_to(:employee_credential, EmployeeCredential)
    belongs_to(:story, Story)
    belongs_to(:developer_poc_credential, DeveloperPocCredential)
    belongs_to(:broker, Broker)
    belongs_to(:cab_booking_requests, BookingRequest)
    belongs_to(:story_tier, StoryTier)
    field(:is_conflict, :boolean, default: false)
    field(:claim_closed, :boolean, default: false)
    field(:has_employee_penalty, :boolean, default: false)
    field(:configuration_types, {:array, :integer})

    belongs_to(:latest_status, RewardsLeadStatus,
      foreign_key: :latest_status_id,
      references: :id
    )

    has_many(:rewards_leads_statuses, RewardsLeadStatus, foreign_key: :rewards_lead_id)

    has_many(:payouts, Payout, foreign_key: :rewards_lead_id)
    has_many(:employee_payouts, EmployeePayout, foreign_key: :rewards_lead_id)

    timestamps()
  end

  @required [:name, :broker_id, :story_id, :developer_poc_credential_id]
  @optional [
    :employee_credential_id,
    :cab_booking_requests_id,
    :visit_date,
    :story_tier_id,
    :release_employee_payout,
    :is_conflict,
    :claim_closed,
    :has_employee_penalty,
    :configuration_types
  ]
  @draft_attrs [:name, :broker_id, :story_id, :employee_credential_id, :cab_booking_requests_id, :story_tier_id]

  @doc false
  def changeset(rewards_lead, attrs) do
    rewards_lead
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_change(:configuration_types, &validate_configuration_types/2)
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:developer_poc_credential_id)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_status_id)
    |> foreign_key_constraint(:story_tier_id)
    |> unique_constraint(:unique_rewards_leads,
      name: :rewards_lead_unique_index,
      message: "A rewards lead with same data exists."
    )
  end

  def draft_changeset(rewards_lead, attrs) do
    rewards_lead
    |> cast(attrs, @draft_attrs)
    |> validate_required(@draft_attrs)
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_status_id)
  end

  def latest_status_changeset(rewards_lead, attrs) do
    rewards_lead
    |> cast(attrs, [:latest_status_id])
    |> validate_required([:latest_status_id])
    |> foreign_key_constraint(:story_id)
    |> foreign_key_constraint(:developer_poc_credential_id)
    |> foreign_key_constraint(:employee_credential_id)
    |> foreign_key_constraint(:broker_id)
    |> foreign_key_constraint(:latest_status_id)
  end

  def create_rewards_lead!(
        lead_name,
        broker_id,
        story,
        developer_poc_credential,
        employee_credential_id,
        visit_date,
        story_tier_id,
        cred,
        configuration_types \\ nil
      ) do
    ch =
      RewardsLead.changeset(%RewardsLead{}, %{
        name: lead_name,
        broker_id: broker_id,
        story_id: story.id,
        developer_poc_credential_id: developer_poc_credential.id,
        employee_credential_id: employee_credential_id,
        visit_date: visit_date,
        story_tier_id: story_tier_id,
        release_employee_payout: true,
        configuration_types: configuration_types
      })

    lead = Repo.insert!(ch)
    level_details = if is_nil(cred.broker.level_id), do: BrokerLevel.level_1(), else: BrokerLevel.get_by_id(cred.broker.level_id)
    RewardsLeadStatus.create_rewards_lead_status!(lead, level_details.create_rewards_lead_status_id)

    # Mimicking/Bypassing employee's actions
    RewardsLeadStatus.create_rewards_lead_status_by_backend!(lead, Status.get_status_id("pending"))
    # Exq.enqueue(
    #   Exq,
    #   "send_notification",
    #   BnApis.Rewards.SendRewardsNotificationWorker,
    #   [lead.id]
    # )

    # Exq.enqueue(Exq, "dev_poc_notification_queue", BnApis.Rewards.DevPocNotifications, [
    #   @create_lead_whatsapp_template,
    #   developer_poc_credential.id,
    #   developer_poc_credential.fcm_id,
    #   developer_poc_credential.platform,
    #   developer_poc_credential.phone_number,
    #   story.name,
    #   cred.broker.name,
    #   cred.phone_number,
    #   lead_name
    # ])

    lead
  end

  def create_draft_rewards_lead!(
        name,
        broker_id,
        story_id,
        employee_credential_id,
        cab_booking_requests_id,
        visit_date,
        story_tier_id
      ) do
    ch =
      RewardsLead.draft_changeset(%RewardsLead{}, %{
        name: name,
        broker_id: broker_id,
        story_id: story_id,
        employee_credential_id: employee_credential_id,
        cab_booking_requests_id: cab_booking_requests_id,
        visit_date: visit_date,
        story_tier_id: story_tier_id,
        release_employee_payout: true
      })

    lead = Repo.insert!(ch)
    RewardsLeadStatus.create_rewards_lead_status!(lead, 6)
    lead
  end

  def update_draft_rewards_lead_to_pending!(
        lead,
        developer_poc_credential,
        employee_credential_id,
        cred,
        configuration_types \\ nil
      ) do
    ch =
      RewardsLead.changeset(lead, %{
        employee_credential_id: employee_credential_id,
        developer_poc_credential_id: developer_poc_credential.id,
        configuration_types: configuration_types
      })

    lead = Repo.update!(ch)
    level_details = if is_nil(cred.broker.level_id), do: BrokerLevel.level_1(), else: BrokerLevel.get_by_id(cred.broker.level_id)
    lead_status = if cred.broker.operating_city == 1, do: level_details.create_rewards_lead_status_id, else: 1
    RewardsLeadStatus.create_rewards_lead_status_by_backend!(lead, lead_status)
    lead
  end

  def update_latest_status!(%RewardsLead{} = lead, latest_status_id) do
    ch =
      RewardsLead.latest_status_changeset(lead, %{
        latest_status_id: latest_status_id
      })

    Repo.update!(ch)
  end

  def get_status_description(lead) do
    status =
      Status.status_list()
      |> get_in([lead.latest_status.status_id, "identifier"])

    case status do
      "pending" ->
        "Developer's Approval Pending"

      "draft" ->
        "Draft"

      "deleted" ->
        "Deleted"

      "rejected" ->
        "Rejected By Developer"

      "approved" ->
        "Approved By Developer"

      "in_review" ->
        "In Review With Manager"

      "rejected_by_manager" ->
        "Rejected By Manager"

      "reward_received" ->
        lead = lead |> Repo.preload(payouts: from(p in Payout, where: p.status == ^@processed_status))

        amount_text =
          case Enum.find(lead.payouts, &(&1.status == @processed_status)) do
            nil ->
              "Amount"

            payout ->
              "Rs. #{trunc(payout.amount / 100)}"
          end

        "#{amount_text} Received"

      "employee_reward_received" ->
        # TODO: handle reward_received and employee_reward_received display separately
        lead = lead |> Repo.preload(payouts: from(p in Payout, where: p.status == ^@processed_status))

        amount_text =
          case Enum.find(lead.payouts, &(&1.status == @processed_status)) do
            nil ->
              "Amount"

            payout ->
              "Rs. #{trunc(payout.amount / 100)}"
          end

        "#{amount_text} Received"
    end
  end

  def get_rewards_leads_query(params) do
    query =
      RewardsLead
      |> join(:inner, [rl], b in Broker, on: rl.broker_id == b.id)
      |> join(:inner, [rl, b], c in Credential, on: c.broker_id == b.id)
      |> join(:inner, [rl, b, c], rls in RewardsLeadStatus, on: rl.latest_status_id == rls.id)
      |> join(:inner, [rl, b, c, rls], s in Story, on: rl.story_id == s.id)
      |> where([rl, b, c, rls], rls.status_id not in [6, 7])

    query =
      if not is_nil(params["assigned_broker_ids"]) do
        query |> where([rl], rl.broker_id in ^params["assigned_broker_ids"])
      else
        query
      end

    query =
      if not is_nil(params["story_ids"]) do
        query |> where([rl], rl.story_id in ^params["story_ids"])
      else
        query
      end

    query =
      if not is_nil(params["broker_ids"]) do
        query |> where([rl], rl.broker_id in ^params["broker_ids"])
      else
        query
      end

    query =
      if not is_nil(params["broker_phone"]) do
        query |> where([rl, b, c], c.phone_number == ^params["broker_phone"])
      else
        query
      end

    query =
      if not is_nil(params["status_ids"]) do
        query |> where([rl, b, c, rls], rls.status_id in ^params["status_ids"])
      else
        query
      end

    query =
      if not is_nil(params["employee_ids"]) do
        query |> where([rl, b, c, rls], rls.status_id in ^params["employee_ids"])
      else
        query
      end

    query =
      if not is_nil(params["developer_ids"]) do
        query |> where([rl, b, c, rls, s], s.developer_id in ^params["developer_ids"])
      else
        query
      end

    query =
      if not is_nil(params["city_id"]) and is_nil(params["assigned_broker_ids"]) do
        query |> where([rl, b], b.operating_city == ^params["city_id"])
      else
        query
      end

    query =
      if not is_nil(params["from_date"]) and not is_nil(params["end_date"]) do
        start_date = if is_binary(params["from_date"]), do: String.to_integer(params["from_date"]), else: params["from_date"]
        start_date = Time.get_start_time_by_timezone(Timex.from_unix(start_date))

        end_date = if is_binary(params["end_date"]), do: String.to_integer(params["end_date"]), else: params["end_date"]
        end_date = Time.get_end_time_by_timezone(Timex.from_unix(end_date))

        query |> where([rl], rl.inserted_at >= ^start_date and rl.inserted_at <= ^end_date)
      else
        query
      end

    query
  end

  def get_rewards_leads(params) do
    page =
      case not is_nil(params["p"]) and is_binary(params["p"]) and Integer.parse(params["p"]) do
        {val, _} -> val
        _ -> 1
      end

    size =
      case not is_nil(params["size"]) and is_binary(params["p"]) and Integer.parse(params["size"]) do
        {val, _} -> val
        _ -> 500
      end

    query = get_rewards_leads_query(params)
    total_count = query |> distinct(true) |> Repo.aggregate(:count, :id)

    leads =
      query
      |> order_by([rl], desc: rl.inserted_at)
      |> limit(^size)
      |> offset(^((page - 1) * size))
      |> distinct(true)
      |> preload([
        :broker,
        :employee_credential,
        :latest_status,
        :story,
        :payouts,
        :employee_payouts,
        :developer_poc_credential,
        broker: [:credentials],
        story: [:polygon, :developer],
        latest_status: [:employee_credential, :developer_poc_credential]
      ])
      |> Repo.all()
      |> Enum.map(fn reward_lead ->
        channel_url =
          if is_nil(reward_lead.employee_credential) do
            nil
          else
            AssignedBrokers.fetch_channel_url(reward_lead.broker.id, reward_lead.employee_credential.id)
          end

        employee =
          if not is_nil(reward_lead.employee_credential) do
            %{
              name: reward_lead.employee_credential.name,
              phone_number: reward_lead.employee_credential.phone_number,
              id: reward_lead.employee_credential.id,
              uuid: reward_lead.employee_credential.uuid
            }
          else
            %{}
          end

        deverloper_poc =
          if not is_nil(reward_lead.developer_poc_credential) do
            %{
              name: reward_lead.developer_poc_credential.name,
              phone_number: reward_lead.developer_poc_credential.phone_number
            }
          else
            %{}
          end

        {_, created_at} = reward_lead.inserted_at |> DateTime.from_naive("Etc/UTC")

        creds = reward_lead.broker.credentials |> Enum.filter(fn crd -> crd.active == true end) |> List.last()

        creds =
          if not is_nil(creds) do
            reward_lead.broker.credentials |> List.last()
          else
            nil
          end

        failure_reason =
          if not is_nil(reward_lead.latest_status.failure_reason_id),
            do: FailureReason.failure_reason_details(reward_lead.latest_status.failure_reason_id),
            else: nil

        lead_status_developer_poc =
          if not is_nil(reward_lead.latest_status.developer_poc_credential) do
            %{
              name: reward_lead.latest_status.developer_poc_credential.name,
              phone_number: reward_lead.latest_status.developer_poc_credential.phone_number
            }
          else
            %{}
          end

        lead_status_employee =
          if not is_nil(reward_lead.latest_status.employee_credential) do
            %{
              name: reward_lead.latest_status.employee_credential.name,
              phone_number: reward_lead.latest_status.employee_credential.phone_number,
              id: reward_lead.latest_status.employee_credential.id,
              uuid: reward_lead.latest_status.employee_credential.uuid
            }
          else
            %{}
          end

        broker_payout_done = Enum.member?(Enum.map(reward_lead.payouts, fn p -> p.status end), @processed_status)

        employee_payout_done = Enum.member?(Enum.map(reward_lead.employee_payouts, fn p -> p.status end), @processed_status)

        %{
          id: reward_lead.id,
          name: reward_lead.name,
          story: %{
            id: reward_lead.story.id,
            name: reward_lead.story.name,
            polygon: if(not is_nil(reward_lead.story.polygon), do: reward_lead.story.polygon.name, else: nil),
            developer: reward_lead.story.developer.name
          },
          broker: %{
            id: reward_lead.broker_id,
            name: reward_lead.broker.name,
            phone_number: if(not is_nil(creds), do: creds.phone_number, else: nil),
            uuid: if(not is_nil(creds), do: creds.uuid, else: nil)
          },
          is_conflict: reward_lead.is_conflict,
          claim_closed: reward_lead.claim_closed,
          employee: employee,
          deverloper_poc: deverloper_poc,
          created_at: created_at |> DateTime.to_unix(),
          lead_status_employee: lead_status_employee,
          status: Status.status_list()[reward_lead.latest_status.status_id],
          status_id: reward_lead.latest_status.status_id,
          broker_payout_done: broker_payout_done,
          employee_payout_done: employee_payout_done,
          failure_reason: %{
            note: reward_lead.latest_status.failure_note,
            reason: if(not is_nil(failure_reason), do: failure_reason["display_name"], else: nil)
          },
          lead_status_developer_poc: lead_status_developer_poc,
          channel_url: channel_url
        }
      end)

    has_more_leads = page < Float.ceil(total_count / size)
    {total_count, has_more_leads, leads, query}
  end

  def get_rewards_leads_aggregate(params) do
    query = get_rewards_leads_query(params)

    status_wise_count =
      query
      |> group_by([rl, b, c, rls], rls.status_id)
      |> select([rl, b, c, rls], {rls.status_id, count(rl.id)})
      |> Repo.all()

    all_count = status_wise_count |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    status_list = Status.status_list()

    status_wise_count_response =
      status_wise_count
      |> Enum.reduce(%{"all" => all_count}, fn data, acc ->
        status = status_list |> get_in([elem(data, 0), "identifier"])
        Map.put(acc, status, elem(data, 1))
      end)

    %{
      "status_wise_count" => %{
        "all" => status_wise_count_response["all"] || 0,
        "in_review" => status_wise_count_response["in_review"] || 0,
        "approval_pending" => status_wise_count_response["pending"] || 0,
        "approved" =>
          (status_wise_count_response["approved"] || 0) + (status_wise_count_response["reward_received"] || 0) +
            (status_wise_count_response["employee_reward_received"] || 0),
        "rejected_by_developer" => status_wise_count_response["rejected"] || 0,
        "rejected_by_manager" => status_wise_count_response["rejected_by_manager"] || 0
      }
    }
  end

  def update_rewards_lead_for_deduping!(lead, deduped_client_name, developer_poc_credential_id) do
    ch =
      RewardsLead.changeset(lead, %{
        name: deduped_client_name,
        developer_poc_credential_id: developer_poc_credential_id
      })

    Repo.update!(ch)
  end

  def get_rate_limit_validation(story_id) do
    two_minutes_ago = Timex.now() |> DateTime.to_naive() |> Timex.shift(minutes: -2)
    one_minutes_ago = Timex.now() |> DateTime.to_naive() |> Timex.shift(minutes: -1)
    five_minutes_ago = Timex.now() |> DateTime.to_naive() |> Timex.shift(minutes: -5)

    reward_leads_limit_1 =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.id == rls.rewards_lead_id and not is_nil(rls.developer_poc_credential_id) and rls.status_id == ^3)
      |> where(
        [rl, rls],
        rl.story_id == ^story_id and rl.inserted_at >= ^two_minutes_ago and rls.inserted_at >= ^five_minutes_ago
      )
      |> distinct(true)
      |> Repo.all()
      |> length

    reward_leads_limit_2 =
      RewardsLead
      |> join(:inner, [rl], rls in RewardsLeadStatus, on: rl.id == rls.rewards_lead_id and not is_nil(rls.developer_poc_credential_id) and rls.status_id == ^3)
      |> where([rl, rls], rl.story_id == ^story_id and rls.inserted_at >= ^one_minutes_ago)
      |> distinct(true)
      |> Repo.all()
      |> length

    reward_leads_limit_1 >= 5 or reward_leads_limit_2 >= 20
  end

  def update_story_tier_for_rewards_lead(rewards_lead, story_tier_id) do
    rewards_lead
    |> changeset(%{
      story_tier_id: story_tier_id
    })
    |> Repo.update()
  end

  defp validate_configuration_types(:configuration_types, configuration_types) do
    case is_list(configuration_types) do
      true ->
        valid_configuration_types_map = parse_configuration_types()

        filtered_configuration_types =
          configuration_types
          |> Enum.reject(fn config_type_id ->
            Map.has_key?(valid_configuration_types_map, config_type_id)
          end)

        if length(filtered_configuration_types) > 0, do: [configuration_types: "Invalid configuration type value"], else: []

      false ->
        [configuration_types: "Invalid configuration type param"]
    end
  end

  defp parse_configuration_types() do
    ConfigurationType.configuration_types_cache()
    |> Enum.reduce(%{}, fn configuration_type, acc ->
      Map.put(acc, configuration_type.id, configuration_type)
    end)
  end
end
