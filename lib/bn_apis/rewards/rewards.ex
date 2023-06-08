defmodule BnApis.Rewards do
  use Ecto.Schema
  use Appsignal.Instrumentation.Decorators

  import Ecto.Query
  import Ecto.Changeset
  alias BnApis.Repo

  alias BnApis.Rewards.{
    RewardsLead,
    RewardsLeadStatus,
    Status,
    FailureReason,
    Payout,
    EmployeePayout,
    StoryTierPlanMapping
  }

  alias BnApis.Accounts.{DeveloperPocCredential, Credential, ProfileType, EmployeeRole, EmployeeVertical}
  alias BnApis.Organizations.Broker
  alias BnApis.Stories.{Story, StoryDeveloperPocMapping}
  alias BnApis.AssignedBrokers
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Helpers.{ApplicationHelper, Token, Time}

  @approved_status_id 3
  @draft_status_id 6
  @delete_status_id 7

  # @manager_approval_whatsapp_notif_template "builder_2"

  def create_lead(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    broker_city = session_data |> get_in(["profile", "operating_city"])
    configuration_types = Map.get(params, "configuration_types")
    params = create_params(params)
    credential = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload(:broker)

    assigned_broker = AssignedBrokers.fetch_one_broker(broker_id)

    employee_credential_id =
      if not is_nil(assigned_broker) do
        assigned_broker.employees_credentials_id
      else
        nil
      end

    if is_nil(credential) do
      channel = ApplicationHelper.get_slack_channel()

      ApplicationHelper.notify_on_slack(
        "Found nil credential for create rewards lead broker_id: #{broker_id}, user_id: #{session_data["user_id"]}",
        channel
      )
    end

    if !is_nil(credential.razorpay_contact_id) &&
         !is_nil(credential.razorpay_fund_account_id) do
      case params do
        %{
          "name" => name,
          "story" => story,
          "developer_poc" => developer_poc,
          "visit_date" => visit_date
        } ->
          has_broker_daily_limit_reached = has_broker_daily_limit_reached?(credential.broker)

          duplicate_reward_lead_for_broker_client_pair = duplicate_reward_lead_for_broker_client_pair?(broker_id, name, story.id, NaiveDateTime.to_date(visit_date))

          is_broker_from_different_city = not Enum.member?(story.operating_cities, broker_city)

          cond do
            not story.is_rewards_enabled ->
              {:error, "Rewards not enabled for the project."}

            has_broker_daily_limit_reached ->
              {:error, "Your daily limit has been reached."}

            is_broker_from_different_city ->
              {:error, "Rewards are allowed in your operating city only."}

            duplicate_reward_lead_for_broker_client_pair ->
              {:error, "Duplicate rewards lead for same broker and same client with same project name and visit date."}

            true ->
              story_tier_id = get_story_tier_id_from_plans(story.id)

              story_tier_id =
                if is_nil(story_tier_id) do
                  story.default_story_tier_id
                else
                  story_tier_id
                end

              Repo.transaction(fn ->
                try do
                  lead =
                    RewardsLead.create_rewards_lead!(
                      name,
                      broker_id,
                      story,
                      developer_poc,
                      employee_credential_id,
                      visit_date,
                      story_tier_id,
                      credential,
                      configuration_types
                    )

                  BnApis.Rewards.UpdateStoryRewardsFlagWorker.perform(story.id)

                  %{"lead_id" => lead.id}
                rescue
                  _ ->
                    Repo.rollback("Unable to store data")
                end
              end)
          end

        _ ->
          {:error, "Invalid params"}
      end
    else
      {:error, "Required banking info not present for this broker"}
    end
  end

  def get_story_tier_id_from_plans(story_id) do
    current_date_time = Timex.now() |> Timex.Timezone.convert("Asia/Kolkata")
    current_date = NaiveDateTime.to_date(current_date_time)

    Repo.one(
      from(l in StoryTierPlanMapping,
        where: l.story_id == ^story_id,
        where: fragment("timezone('asia/kolkata', timezone('utc', ?))::date", l.start_date) <= ^current_date,
        where: fragment("timezone('asia/kolkata', timezone('utc', ?))::date", l.end_date) >= ^current_date,
        where: l.active == true,
        select: l.story_tier_id
      )
      |> limit(1)
    )
  end

  def update_lead(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    configuration_types = Map.get(params, "configuration_types")
    params = create_params(params)
    credential = Credential.get_credential_from_broker_id(broker_id) |> Repo.preload(:broker)

    assigned_broker = AssignedBrokers.fetch_one_broker(broker_id)

    employee_credential_id =
      if not is_nil(assigned_broker) do
        assigned_broker.employees_credentials_id
      else
        nil
      end

    if is_nil(credential) do
      channel = ApplicationHelper.get_slack_channel()

      ApplicationHelper.notify_on_slack(
        "Found nil credential for update rewards lead broker_id: #{broker_id}, user_id: #{session_data["user_id"]}",
        channel
      )
    end

    rewards_lead = RewardsLead |> where([rl], rl.id == ^params["id"] and rl.broker_id == ^broker_id) |> Repo.one()

    if is_nil(rewards_lead) do
      {:error, "Rewards lead not found"}
    else
      if !is_nil(credential.razorpay_contact_id) &&
           !is_nil(credential.razorpay_fund_account_id) do
        case params do
          %{
            "story" => story,
            "developer_poc" => developer_poc
          } ->
            has_broker_daily_limit_reached = has_broker_daily_limit_reached?(credential.broker)

            if has_broker_daily_limit_reached do
              {:error, "Your daily limit has been reached"}
            else
              Repo.transaction(fn ->
                try do
                  lead =
                    RewardsLead.update_draft_rewards_lead_to_pending!(
                      rewards_lead,
                      developer_poc,
                      employee_credential_id,
                      credential,
                      configuration_types
                    )

                  BnApis.Rewards.UpdateStoryRewardsFlagWorker.perform(story.id)

                  %{"lead_id" => lead.id}
                rescue
                  _ ->
                    Repo.rollback("Unable to store data")
                end
              end)
            end

          _ ->
            {:error, "Invalid params"}
        end
      else
        {:error, "Required banking info not present for this broker"}
      end
    end
  end

  def delete_lead(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])
    rewards_lead = RewardsLead |> where([rl], rl.id == ^params["id"] and rl.broker_id == ^broker_id) |> Repo.one()

    if is_nil(rewards_lead) do
      {:error, "Rewards lead not found"}
    else
      rewards_lead = rewards_lead |> Repo.preload(:latest_status)
      status = Status.status_list() |> get_in([rewards_lead.latest_status.status_id, "identifier"])

      if status != "draft" do
        {:error, "Rewards lead not in draft status to delete"}
      else
        RewardsLeadStatus.create_rewards_lead_status_by_backend!(
          rewards_lead,
          @delete_status_id,
          params["failure_note"]
        )

        {:ok, %{"lead_id" => rewards_lead.id}}
      end
    end
  end

  @decorate transaction()
  def get_leads(params, session_data, _with_drafts \\ false) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    status_ids =
      case params["status_ids"] do
        nil ->
          []

        status_ids when is_binary(status_ids) ->
          status_ids
          |> String.split(",")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&String.to_integer(String.trim(&1)))
      end

    page_no = (params["p"] || "1") |> String.to_integer()
    {:ok, filter_leads(broker_id, status_ids, page_no, nil, false, false)}
  end

  @decorate transaction()
  def get_draft_leads(params, session_data) do
    broker_id = session_data |> get_in(["profile", "broker_id"])

    status_ids = [@draft_status_id]

    page_no = (params["p"] || "1") |> String.to_integer()
    {:ok, filter_leads(broker_id, status_ids, page_no, nil, true)}
  end

  def draft_leads_count(broker_id) do
    now_time = Timex.now() |> Timex.to_naive_datetime()

    RewardsLead
    |> where([l], l.broker_id == ^broker_id)
    |> join(:inner, [l], ls in RewardsLeadStatus, on: l.latest_status_id == ls.id)
    |> join(:inner, [l, ls], br in BookingRequest, on: l.cab_booking_requests_id == br.id)
    |> where([l, ls, br], br.pickup_time <= ^now_time and ls.status_id == ^@draft_status_id)
    |> Repo.all()
    |> length()
  end

  @decorate transaction()
  def get_broker_history(params, session_data) do
    developer_poc_credential_id = session_data |> get_in(["user_id"])
    broker_id = params["broker_id"]

    status_ids =
      case params["status_ids"] do
        nil ->
          []

        status_ids when is_binary(status_ids) ->
          status_ids
          |> String.split(",")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(&String.to_integer(String.trim(&1)))
      end

    page_no = (params["p"] || "1") |> String.to_integer()

    {:ok, filter_leads(broker_id, status_ids, page_no, developer_poc_credential_id)}
  end

  defp create_params(params) do
    story_uuid = params["story_uuid"]

    story =
      Story
      |> preload([:polygon, :story_developer_poc_mappings, story_developer_poc_mappings: [:developer_poc_credential]])
      |> where([s], s.uuid == ^story_uuid)
      |> Repo.one()

    # visit_date = if not is_nil(params["visit_date"]) do
    #   sv_date = if is_binary(params["visit_date"]), do: String.to_integer(params["visit_date"]), else: params["visit_date"]
    #   {_, datetime} = DateTime.from_unix(sv_date)
    #   datetime |> DateTime.to_naive
    # else
    #   {_, datetime} = DateTime.now("Etc/UTC")
    #   datetime |> DateTime.to_naive
    # end

    {_, datetime} = DateTime.now("Etc/UTC")
    visit_date = datetime |> DateTime.to_naive()

    params = params |> Map.merge(%{"visit_date" => visit_date})

    if !is_nil(story) do
      params = params |> Map.merge(%{"story" => story})

      developer_poc =
        Story.get_developer_pocs(story)
        |> Enum.find(&(&1.uuid == params["developer_poc_uuid"]))

      if !is_nil(developer_poc) do
        params |> Map.merge(%{"developer_poc" => developer_poc})
      else
        params
      end
    else
      params
    end
  end

  @decorate transaction_event()
  defp filter_leads(
         broker_id,
         status_ids,
         page_no,
         developer_poc_credential_id,
         only_drafts \\ false,
         with_drafts \\ false
       ) do
    limit = 30
    offset = (page_no - 1) * limit

    query =
      RewardsLead
      |> join(:inner, [l], ls in RewardsLeadStatus, on: l.latest_status_id == ls.id)
      |> where([l, ls], l.broker_id == ^broker_id and ls.status_id != ^@delete_status_id)
      |> preload([l, ls], latest_status: ls)
      |> maybe_filter_by_developer_story(developer_poc_credential_id)

    query =
      if only_drafts do
        now_time = Timex.now() |> Timex.to_naive_datetime()

        query
        |> join(:inner, [l, ls], br in BookingRequest, on: l.cab_booking_requests_id == br.id)
        |> where([l, ls, br], br.pickup_time <= ^now_time and ls.status_id != ^@draft_status_id)
      else
        if Enum.empty?(status_ids) do
          # if with_drafts == false do
          query |> where([l, ls], ls.status_id != ^@draft_status_id)
          # else
          #   if with_drafts do
          #     now_time = Timex.now() |> Timex.to_naive_datetime
          #     query
          #     |> join(:left, [l, ls], br in BookingRequest, on: l.cab_booking_requests_id == br.id)
          #     |> where([l, ls, br], is_nil(l.cab_booking_requests_id) or (not is_nil(l.cab_booking_requests_id) and br.pickup_time <= ^now_time))
          #   else
          #     query
          #   end
          # end
        else
          status_ids_to_query = if with_drafts == true, do: status_ids, else: status_ids |> Enum.reject(&(&1 == @draft_status_id))

          if Enum.member?(status_ids_to_query, @draft_status_id) do
            now_time = Timex.now() |> Timex.to_naive_datetime()

            query
            |> join(:left, [l, ls], br in BookingRequest, on: l.cab_booking_requests_id == br.id)
            |> where(
              [l, ls, br],
              (is_nil(l.cab_booking_requests_id) or
                 (not is_nil(l.cab_booking_requests_id) and br.pickup_time <= ^now_time)) and
                ls.status_id in ^status_ids_to_query
            )
          else
            query
            |> where([l, ls], ls.status_id in ^status_ids_to_query)
          end
        end
      end

    approve_lead_query = from rls in RewardsLeadStatus, where: rls.status_id == @approved_status_id

    results =
      query
      |> offset(^offset)
      |> limit(^(limit + 1))
      |> order_by([l, ls, br], desc: l.inserted_at)
      |> select([l, ...], l)
      |> Repo.all()
      |> Repo.preload([
        :developer_poc_credential,
        :cab_booking_requests,
        story: [:polygon],
        rewards_leads_statuses: approve_lead_query
      ])
      |> Enum.map(fn lead ->
        updated_at = if is_nil(lead.cab_booking_requests), do: lead.inserted_at, else: lead.cab_booking_requests.pickup_time

        %{
          "lead" => %{
            "id" => lead.id,
            "name" => lead.name,
            "status" => Status.status_details(lead.latest_status.status_id),
            "configuration_types" => lead.configuration_types,
            "updated_at" => Time.naive_second_to_millisecond(updated_at),
            "updated_at_unix" => updated_at |> Timex.to_datetime() |> DateTime.to_unix(),
            "status_description" => RewardsLead.get_status_description(lead),
            "is_auto_approved" => is_lead_auto_approved(lead),
            "visit_date" => Time.naive_second_to_millisecond(lead.visit_date || updated_at),
            "visit_date_unix" => (lead.visit_date || updated_at) |> Timex.to_datetime() |> DateTime.to_unix()
          },
          "story" => Story.get_story_details_for_rewards(lead.story),
          "developer_poc" => DeveloperPocCredential.to_map(lead.developer_poc_credential),
          "payout_failure" => Payout.get_payout_failure_reason(lead)
        }
      end)

    %{
      "results" => Enum.slice(results, 0, limit),
      "has_more_page" => length(results) > limit,
      "filters" => Status.get_status_filter_list(status_ids)
    }
  end

  def get_pending_rewards_request(params, session_data) do
    developer_poc_id = session_data |> get_in(["user_id"])
    page_no = (params["p"] || "1") |> String.to_integer()
    {:ok, get_rewards_request_for_developer_poc(developer_poc_id, [1], page_no)}
  end

  def get_rejected_rewards_request(params, session_data) do
    developer_poc_id = session_data |> get_in(["user_id"])
    page_no = (params["p"] || "1") |> String.to_integer()
    {:ok, get_rewards_request_for_developer_poc(developer_poc_id, [2], page_no)}
  end

  def get_approved_rewards_request(params, session_data) do
    developer_poc_id = session_data |> get_in(["user_id"])
    page_no = (params["p"] || "1") |> String.to_integer()

    {:ok, get_rewards_request_for_developer_poc(developer_poc_id, [3, 4, 5], page_no)}
  end

  def search_leads(%{"q" => q}, session_data) when is_binary(q) and q != "" do
    developer_poc_id = session_data |> get_in(["user_id"])
    name_query = "%#{String.downcase(q)}%"

    story_ids =
      StoryDeveloperPocMapping
      |> where([m], m.developer_poc_credential_id == ^developer_poc_id and m.active == ^true)
      |> select([m], m.story_id)
      |> Repo.all()

    results =
      RewardsLead
      |> where([l], l.story_id in ^story_ids)
      |> join(:inner, [l], b in Broker, on: l.broker_id == b.id)
      |> join(:inner, [l, b], rls in RewardsLeadStatus, on: rls.rewards_lead_id == l.id)
      |> where([l, b], fragment("lower(?) like ?", b.name, ^name_query))
      |> where([l, b, rls], rls.status_id in [1, 2, 3, 4, 5])
      |> distinct(true)
      |> limit(15)
      |> select([l], l)
      |> Repo.all()
      |> build_rewards_response_for_developer_poc()

    {:ok, %{"results" => results}}
  end

  def search_leads(_params, _session_data) do
    {:ok, %{"results" => []}}
  end

  defp get_rewards_request_for_developer_poc(
         developer_poc_id,
         status_ids,
         page_no
       ) do
    developer_poc = Repo.get_by(DeveloperPocCredential, id: developer_poc_id)

    limit = 30
    offset = (page_no - 1) * limit

    total_results_count =
      get_rewards_query_for_developer_poc(developer_poc.id, status_ids)
      |> select([l, ...], count(l.id))
      |> Repo.one()

    has_more_page = total_results_count > page_no * limit

    results =
      get_rewards_query_for_developer_poc(developer_poc.id, status_ids)
      |> offset(^offset)
      |> limit(^limit)
      |> order_by([l, ..., ls], desc: l.inserted_at)
      |> select([l, ...], l)
      |> Repo.all()
      |> build_rewards_response_for_developer_poc()

    %{
      "results" => results,
      "has_more_page" => has_more_page,
      "total_results_count" => total_results_count
    }
  end

  @decorate transaction()
  def approve_rewards_request_by_developer_poc(params, session_data, false, device_info \\ %{}) do
    developer_poc_id = session_data |> get_in(["user_id"])
    status_id = 3

    case validate_reward_status_change_params(
           developer_poc_id,
           params["lead_id"],
           status_id
         ) do
      {:ok, rewards_lead} ->
        rewards_lead = rewards_lead |> Repo.preload([:latest_status, :story, :story_tier])
        balances = Story.get_story_balances(rewards_lead.story)

        rewards_lead_amount =
          if not is_nil(rewards_lead.story_tier) do
            rewards_lead.story_tier.amount
          else
            300
          end

        if balances[:total_credits_amount] - balances[:total_debits_amount] - balances[:total_approved_amount] >=
             rewards_lead_amount do
          if rewards_lead.latest_status.status_id != status_id do
            Repo.transaction(fn ->
              try do
                should_raise_alert = RewardsLead.get_rate_limit_validation(rewards_lead.story_id)

                if should_raise_alert do
                  story = Repo.get(Story, rewards_lead.story_id)

                  story
                  |> cast(%{"blocked_for_reward_approval" => true}, [:blocked_for_reward_approval])
                  |> Repo.update!()

                  Token.destroy_all_user_tokens(developer_poc_id, ProfileType.developer_poc().id)
                  dpoc = Repo.get(DeveloperPocCredential, developer_poc_id)

                  message = "Rewards approval blocked for #{story.name}. Approver details - #{dpoc.name}, #{dpoc.phone_number}"
                  send_whatsapp_messages(message)
                  channel = ApplicationHelper.get_slack_channel()

                  ApplicationHelper.notify_on_slack(
                    message,
                    channel
                  )
                end

                RewardsLeadStatus.create_rewards_lead_status_by_poc!(
                  rewards_lead,
                  status_id,
                  developer_poc_id,
                  nil,
                  nil,
                  device_info
                )

                enqueue_rewards_workers(rewards_lead.story.id, rewards_lead.id)

                %{"message" => "Request approved successfully"}
              rescue
                error ->
                  Repo.rollback(Exception.message(error))
              end
            end)
          else
            {:error, "Lead already present in approved state"}
          end
        else
          {:error, "Insufficient rewards balance to process broker payouts!"}
        end

      response ->
        response
    end
  end

  @decorate transaction_event()
  defp send_whatsapp_messages(message) do
    Exq.enqueue(Exq, "send_whatsapp_message", BnApis.Whatsapp.SendWhatsappMessageWorker, ["7768822261", "generic", [message]])
    Exq.enqueue(Exq, "send_whatsapp_message", BnApis.Whatsapp.SendWhatsappMessageWorker, ["9819619866", "generic", [message]])
  end

  @decorate transaction_event()
  defp enqueue_rewards_workers(story_id, lead_id) do
    Exq.enqueue(Exq, "story", BnApis.Rewards.UpdateStoryRewardsFlagWorker, [story_id])
    Exq.enqueue(Exq, "payments", BnApis.Rewards.GeneratePayoutWorker, [lead_id])
    # Exq.enqueue(Exq, "employee_payments", BnApis.Rewards.GenerateEmployeePayoutWorker, [lead_id])
    Exq.enqueue(Exq, "send_notification", BnApis.Rewards.SendRewardsNotificationWorker, [lead_id])
  end

  def approved_reward_leads_count(broker_ids) do
    approved_status_id = [3, 4]

    RewardsLead
    |> where([l], l.broker_id in ^broker_ids)
    |> join(:inner, [l], ls in RewardsLeadStatus, on: l.latest_status_id == ls.id)
    |> where([l, ..., ls], ls.status_id in ^approved_status_id)
    |> distinct(true)
    |> Repo.aggregate(:count, :id)
  end

  def reject_rewards_request_by_developer_poc(params, session_data, device_info \\ %{}) do
    developer_poc_id = session_data |> get_in(["user_id"])
    status_id = 2

    case validate_reward_status_change_params(
           developer_poc_id,
           params["lead_id"],
           status_id
         ) do
      {:ok, rewards_lead} ->
        rewards_lead = rewards_lead |> Repo.preload([:latest_status, :story])

        cond do
          rewards_lead.latest_status.status_id == status_id ->
            {:error, "Lead already present in rejected state"}

          rewards_lead.latest_status.status_id != 1 ->
            {:error, "Lead cannot be rejected"}

          true ->
            RewardsLeadStatus.create_rewards_lead_status_by_poc!(
              rewards_lead,
              status_id,
              developer_poc_id,
              params["failure_reason_id"],
              params["failure_note"],
              device_info
            )

            BnApis.Rewards.UpdateStoryRewardsFlagWorker.perform(rewards_lead.story_id)

            Exq.enqueue(
              Exq,
              "send_notification",
              BnApis.Rewards.SendRewardsNotificationWorker,
              [rewards_lead.id]
            )

            {:ok, %{"message" => "Request rejected successfully"}}
        end

      response ->
        response
    end
  end

  def handle_razorpay_webhook(params) do
    handle_payout_webhook(params)
    handle_employee_payout_webhook(params)
    %{"message" => "Success"}
  end

  def handle_payout_webhook(params) do
    Repo.transaction(fn ->
      try do
        payout_id = params["payload"]["payout"]["entity"]["id"]
        status = params["payload"]["payout"]["entity"]["status"]
        payout = Repo.get_by(Payout, payout_id: payout_id)

        if not is_nil(payout) do
          Payout.update_status!(payout, status, params)
          rewards_lead = Repo.get_by(RewardsLead, id: payout.rewards_lead_id)

          Exq.enqueue(
            Exq,
            "send_notification",
            BnApis.Rewards.SendRewardsNotificationWorker,
            [rewards_lead.id]
          )
        end
      rescue
        _ ->
          Repo.rollback("Unable to process payout webhook")
      end
    end)
  end

  def handle_employee_payout_webhook(params) do
    Repo.transaction(fn ->
      try do
        payout_id = params["payload"]["payout"]["entity"]["id"]
        status = params["payload"]["payout"]["entity"]["status"]
        employee_payout = Repo.get_by(EmployeePayout, payout_id: payout_id)

        if not is_nil(employee_payout) do
          EmployeePayout.update_status!(employee_payout, status, params)
        end
      rescue
        _ ->
          Repo.rollback("Unable to process employee payout webhook")
      end
    end)
  end

  defp get_rewards_query_for_developer_poc(developer_poc_id, status_ids) do
    story_ids =
      StoryDeveloperPocMapping
      |> where([m], m.developer_poc_credential_id == ^developer_poc_id and m.active == ^true)
      |> select([m], m.story_id)
      |> Repo.all()

    RewardsLead
    |> where([l], l.story_id in ^story_ids)
    |> join(:inner, [l], ls in RewardsLeadStatus, on: l.latest_status_id == ls.id)
    |> where([l, ..., ls], ls.status_id in ^status_ids)
  end

  defp build_rewards_response_for_developer_poc(leads) do
    leads
    |> Repo.preload([:story, :broker, :latest_status, :rewards_leads_statuses, story: [:polygon]])
    |> Enum.map(fn lead ->
      broker = lead.broker
      credential = Credential.get_any_credential_from_broker_id(broker.id)
      credential = credential |> Repo.preload([:organization])

      %{
        "lead" => %{
          "id" => lead.id,
          "name" => lead.name,
          "configuration_types" => lead.configuration_types,
          "status" => Status.status_details(lead.latest_status.status_id),
          "updated_at" => lead.latest_status.updated_at,
          "failure_reason" => FailureReason.failure_reason_details(lead.latest_status.failure_reason_id),
          "failure_note" => lead.latest_status.failure_note,
          "is_auto_approved" => is_lead_auto_approved(lead),
          "visit_date" =>
            if not is_nil(lead.visit_date) do
              lead.visit_date |> Time.naive_to_epoch()
            else
              lead.visit_date
            end
        },
        "broker" => %{
          "id" => broker.id,
          "name" => broker.name,
          "uuid" => credential.uuid,
          "profile_image_url" => Broker.get_profile_image_url(broker),
          "phone_number" => Broker.get_credential_data(broker)["phone_number"],
          "organization" => credential.organization.name
        },
        "story" => Story.get_story_details_for_rewards(lead.story)
      }
    end)
  end

  def action_on_rewards_request_by_manager(logged_in_user, params, next_status) do
    cred_query = from(c in Credential, where: c.active == true, limit: 1)

    rewards_lead =
      RewardsLead
      |> where([rl], rl.id == ^params["lead_id"])
      |> preload([:developer_poc_credential, :story, :latest_status, broker: [credentials: ^cred_query]])
      |> Repo.one()

    # cred = rewards_lead.broker.credentials |> List.first()

    # visit_date = Time.get_formatted_datetime(rewards_lead.visit_date, "%d/%m/%Y")

    broker_id = rewards_lead.broker_id
    assigned_brokers = AssignedBrokers.fetch_all_active_assigned_brokers(logged_in_user[:user_id])

    cond do
      logged_in_user[:vertical_id] !== EmployeeVertical.get_vertical_by_identifier("PROJECT")["id"] ->
        {:error, "Not allowed to take action on the given lead"}

      next_status == "claim_closed" ->
        rewards_lead |> RewardsLead.changeset(%{"claim_closed" => true}) |> Repo.update!()
        {:ok, "Action taken by manager successfully!"}

      Status.get_status_id(next_status) |> is_nil() ->
        {:error, "Invalid request"}

      !Enum.member?(assigned_brokers, broker_id) and
          !Enum.member?(
            [EmployeeRole.broker_admin().id, EmployeeRole.super().id, EmployeeRole.admin().id],
            logged_in_user[:employee_role_id]
          ) ->
        {:error, "Not allowed to take action on the given lead"}

      next_status == "pending" and !Enum.member?([2, 8, 9], rewards_lead.latest_status.status_id) ->
        {:error, "Lead not in review or rejected by manager status"}

      next_status == "rejected_by_manager" and rewards_lead.latest_status.status_id != 8 ->
        {:error, "Lead not in review status"}

      next_status == "claim_closed" and rewards_lead.latest_status.status_id != 2 ->
        {:error, "Lead not rejected in rejected by developer status"}

      rewards_lead.claim_closed ->
        {:error, "Reward is closed for further actions"}

      true ->
        RewardsLeadStatus.create_rewards_lead_status_by_manager!(
          rewards_lead,
          Status.get_status_id(next_status),
          logged_in_user[:user_id],
          params["failure_reason_id"],
          params["failure_note"]
        )

        # Exq.enqueue(Exq, "dev_poc_notification_queue", BnApis.Rewards.DevPocNotifications, [
        #   @manager_approval_whatsapp_notif_template,
        #   next_status,
        #   rewards_lead.name,
        #   visit_date,
        #   rewards_lead.broker.name,
        #   rewards_lead.story.name,
        #   rewards_lead.developer_poc_credential.id,
        #   rewards_lead.developer_poc_credential.fcm_id,
        #   rewards_lead.developer_poc_credential.platform,
        #   rewards_lead.developer_poc_credential.phone_number,
        #   logged_in_user[:name],
        #   logged_in_user[:phone_number],
        #   cred.phone_number
        # ])

        Exq.enqueue(
          Exq,
          "send_notification",
          BnApis.Rewards.SendRewardsNotificationWorker,
          [rewards_lead.id]
        )

        BnApis.Rewards.UpdateStoryRewardsFlagWorker.perform(rewards_lead.story_id)

        {:ok, "Action taken by manager successfully!"}
    end
  end

  defp validate_reward_status_change_params(_developer_poc_id, nil, nil) do
    {:error, "Invalid lead id"}
  end

  defp validate_reward_status_change_params(developer_poc_id, reward_lead_id, to_status_id) do
    rewards_lead = Repo.get_by(RewardsLead, id: reward_lead_id) |> Repo.preload([:story, :latest_status])

    supported_story_ids =
      StoryDeveloperPocMapping
      |> where([m], m.developer_poc_credential_id == ^developer_poc_id)
      |> select([m], m.story_id)
      |> Repo.all()

    developer_poc = Repo.get(DeveloperPocCredential, developer_poc_id)

    cond do
      is_nil(rewards_lead) ->
        {:error, "Invalid lead id"}

      developer_poc.phone_number == "9999999999" ->
        {:error, "Test users cannot take action on live data."}

      Enum.member?([3, 4, 5], rewards_lead.latest_status.status_id) and to_status_id in [3, 4] ->
        {:error, "Lead is already in approved status."}

      rewards_lead.latest_status.status_id == 2 and to_status_id == 2 ->
        {:error, "Lead is already in rejected status."}

      rewards_lead.story.blocked_for_reward_approval ->
        {:error, "Action blocked to ensure better security. Contact your relationship manager."}

      !Enum.member?(supported_story_ids, rewards_lead.story_id) ->
        {:error, "No access to this lead"}

      true ->
        {:ok, rewards_lead}
    end
  end

  defp has_broker_daily_limit_reached?(broker) do
    daily_max_lead_count = if not is_nil(broker.max_rewards_per_day), do: broker.max_rewards_per_day, else: 5

    today =
      Timex.now()
      |> Timex.Timezone.convert("Asia/Kolkata")
      |> Timex.beginning_of_day()

    brokers_today_lead_count =
      Repo.one(
        from(l in RewardsLead,
          where: l.broker_id == ^broker.id,
          where: l.inserted_at >= ^today,
          select: count(l.id)
        )
      )

    brokers_today_lead_count >= daily_max_lead_count
  end

  defp duplicate_reward_lead_for_broker_client_pair?(broker_id, client_name, story_id, visit_date) do
    duplicate_lead_count =
      Repo.one(
        from(lead in RewardsLead,
          where: lead.broker_id == ^broker_id,
          where: lead.story_id == ^story_id,
          where: lead.name == ^client_name,
          where: fragment("?::date", lead.visit_date) == ^visit_date,
          select: count(lead.id)
        )
      )

    duplicate_lead_count >= 1
  end

  defp maybe_filter_by_developer_story(query, nil), do: query

  defp maybe_filter_by_developer_story(query, developer_poc_credential_id) do
    story_ids =
      StoryDeveloperPocMapping
      |> where([m], m.developer_poc_credential_id == ^developer_poc_credential_id and m.active == ^true)
      |> select([m], m.story_id)
      |> Repo.all()

    where(query, [l], l.story_id in ^story_ids)
  end

  defp is_lead_auto_approved(lead) do
    case DeveloperPocCredential.fetch_bn_approver_credential() do
      nil ->
        case Enum.find(lead.rewards_leads_statuses, nil, fn s -> s.status_id == 3 and s.developer_poc_credential_id == nil end) do
          nil -> false
          _data -> true
        end

      auto_approver ->
        case Enum.find(lead.rewards_leads_statuses, nil, fn s ->
               s.status_id == 3 and (s.developer_poc_credential_id == auto_approver.id or s.developer_poc_credential_id == nil)
             end) do
          nil -> false
          _data -> true
        end
    end
  end
end
