defmodule BnApis.Helpers.AssignedBrokerHelper do
  alias BnApis.{AssignedBrokers, AssignedBrokerNotes}
  alias BnApis.Helpers.{Time, ApplicationHelper, ExternalApiHelper}
  alias BnApis.{Repo, Organizations, Posts}
  alias BnApis.CallLogs.AssignedBrokerCallLogs
  alias BnApis.Organizations.Organization
  alias BnApis.Places.Polygon
  alias BnApis.Accounts.{EmployeeCredential, EmployeeVertical}

  def fetch_all_active_assigned_brokers(employee_credential_id) do
    employee_credential_id
    |> AssignedBrokers.fetch_all_active_assigned_brokers()
  end

  def fetch_all_unassigned_brokers() do
    AssignedBrokers.fetch_all_unassigned_brokers()
    |> Enum.group_by(& &1[:org_uuid])
    |> process_all_unassigned_response()
  end

  def assigned_broker_data(assigned_broker_ids) do
    assigned_broker_ids
    |> AssignedBrokers.assigned_broker_data()
  end

  def assigned_organization_data(assigned_broker_ids) do
    assigned_broker_ids
    |> AssignedBrokers.assigned_organization_data()
  end

  def dashboard_assigned_broker_data(employee_credential_id, assigned_broker_ids) do
    employee_credential_id
    |> AssignedBrokers.dashboard_assigned_broker_data(assigned_broker_ids)
  end

  def create_employee_assignments(logged_in_credential_id, employee_credential_id, broker_ids) do
    logged_in_credential_id
    |> AssignedBrokers.create_employee_assignments(employee_credential_id, broker_ids)
  end

  def remove_employee_assignments(logged_in_credential_id, employee_credential_id, remove_broker_ids) do
    logged_in_credential_id
    |> AssignedBrokers.remove_employee_assignments(employee_credential_id, remove_broker_ids)
  end

  def get_employee_analytics(employee_credential_id) do
    assigned_broker_ids = fetch_all_active_assigned_brokers(employee_credential_id)
    assigned_broker_details = employee_credential_id |> dashboard_assigned_broker_data(assigned_broker_ids)
    total_assigned_brokers = assigned_broker_details |> length()
    total_inactive_brokers = Enum.count(assigned_broker_details, & &1[:last_post])
    total_marked_as_lost_brokers = Enum.count(assigned_broker_details, & &1[:is_marked_lost])

    %{
      total_assigned_brokers: total_assigned_brokers,
      total_inactive_brokers: total_inactive_brokers,
      total_marked_as_lost_brokers: total_marked_as_lost_brokers,
      total_active_brokers: total_assigned_brokers - total_inactive_brokers - total_marked_as_lost_brokers
    }
  end

  def snooze(employee_credential_id, broker_id, snoozed_till_epoch) do
    assigned_broker = AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id)
    snoozed_till = snoozed_till_epoch |> Time.epoch_to_naive()

    snooze_params = %{
      "snoozed" => true,
      "snoozed_till" => snoozed_till
    }

    assigned_broker |> AssignedBrokers.update(snooze_params)
  end

  def mark_lost(employee_credential_id, broker_id, reason) do
    assigned_broker = AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id)

    mark_lost_params = %{
      is_marked_lost: true,
      lost_reason: reason
    }

    assigned_broker |> AssignedBrokers.update(mark_lost_params)
  end

  def fetch_all_assignees_info(broker_ids) do
    broker_ids |> AssignedBrokers.fetch_all_assignees_info()
  end

  def create_note(employee_credential_id, broker_id, params) do
    assigned_broker = AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id)
    params = put_in(params, ["employees_assigned_brokers_id"], assigned_broker.id)
    params |> AssignedBrokerNotes.create()
  end

  def create_call_log(employee_credential_id, broker_id) do
    assigned_broker = AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id)
    AssignedBrokerCallLogs.create(%{employees_assigned_brokers_id: assigned_broker.id})
  end

  def search_assigned_broker(employee_credential_id, search_query) do
    AssignedBrokers.search_assigned_broker_query(employee_credential_id, search_query)
    |> Repo.all()
  end

  def search_assigned_organization(employee_credential_id, search_query) do
    AssignedBrokers.search_assigned_organization_query(employee_credential_id, search_query)
    |> Repo.all()
    |> add_organization_polygon_info()
  end

  def fetch_assigned_org_details(employee_credential_id, org_uuid) do
    if ApplicationHelper.get_onground_apis_allowed() == "false" do
      %{}
    else
      org = Organizations.get_organization_by_uuid(org_uuid)
      org_broker_ids = Organizations.get_organization_brokers(org_uuid) |> Enum.map(& &1[:broker_id])

      AssignedBrokers.dashboard_assigned_broker_data(employee_credential_id, org_broker_ids)
      |> filter_organization_brokers(org_uuid)
      |> add_broker_analytics(org.id)
      |> group_dashboard_data()
      |> sort_organization_wise_brokers()
      |> add_organization_analytics(org)
      |> process_organization_response()
    end
  end

  def fetch_broker_data(employee_credential_id, broker_id) do
    assigned_broker = AssignedBrokers.fetch_employee_broker(employee_credential_id, broker_id)
    broker_data = AssignedBrokers.dashboard_assigned_broker_data(employee_credential_id, [broker_id])

    broker_data
    |> List.first()
    |> Map.merge(%{
      history: fetch_history(assigned_broker)
    })
    |> Map.merge(add_snooze_info(assigned_broker))
    |> Map.put("channel_url", AssignedBrokers.fetch_channel_url(broker_id, employee_credential_id))
  end

  def fetch_history(employee_assigned_broker) do
    ([] ++
       AssignedBrokerNotes.fetch_all_notes(employee_assigned_broker.id) ++
       AssignedBrokerCallLogs.fetch_all_call_logs(employee_assigned_broker.id))
    |> Enum.sort_by(& &1[:inserted_at], &>=/2)
  end

  def filter_and_sort_by_broker(data) do
    org_data = process_dashboard_data(data)
    broker_list = Enum.reduce(org_data[:organisation_data], [], fn ele, acc -> acc ++ ele[:brokers_data] end)
    Enum.sort(broker_list, &(&1.name <= &2.name))
  end

  def process_dashboard_data(data) do
    data =
      data
      |> group_dashboard_data()
      |> sort_organization_wise_brokers()
      |> filter_organization()
      |> sort_organization()

    %{
      organisation_data: data
    }
  end

  def add_snooze_info(assigned_broker) do
    %{
      snoozed: AssignedBrokers.is_snoozed?(assigned_broker),
      snoozed_till_epoch: assigned_broker && assigned_broker.snoozed_till |> Time.naive_to_epoch(),
      snoozed_till: assigned_broker && assigned_broker.snoozed_till
    }
  end

  def add_lost_info(assigned_broker) do
    %{
      is_marked_lost: (assigned_broker && assigned_broker.is_marked_lost) || false,
      lost_reason: (assigned_broker && assigned_broker.lost_reason) || ""
    }
  end

  def segregate_snooozed_brokers(brokers_list) do
    {today_snoozed_brokers_list, remaining_snoozed_brokers_list} = brokers_list |> Enum.split_with(&today_snooze_check(&1))

    {future_snoozed_brokers_list, past_snoozed_brokers_list} = remaining_snoozed_brokers_list |> Enum.split_with(&future_snooze_check(&1))

    {past_snoozed_brokers_list, today_snoozed_brokers_list, future_snoozed_brokers_list}
  end

  def sort_snoozed_brokers({past_snoozed_brokers_list, today_snoozed_brokers_list, future_snoozed_brokers_list}) do
    past_snoozed_brokers_list = past_snoozed_brokers_list |> Enum.sort_by(& &1[:snoozed_till_epoch])
    today_snoozed_brokers_list = today_snoozed_brokers_list |> Enum.sort_by(& &1[:snoozed_till_epoch])
    future_snoozed_brokers_list = future_snoozed_brokers_list |> Enum.sort_by(& &1[:snoozed_till_epoch])
    {past_snoozed_brokers_list, today_snoozed_brokers_list, future_snoozed_brokers_list}
  end

  def sort_remaining_brokers({inactive_brokers_list, active_brokers_list}) do
    inactive_brokers_list = inactive_brokers_list |> Enum.sort_by(& &1[:last_post_days], &>=/2)
    active_brokers_list = active_brokers_list |> Enum.sort_by(& &1[:last_post_days], &>=/2)
    {inactive_brokers_list, active_brokers_list}
  end

  def future_snooze_check(broker_data) do
    broker_data[:snoozed] && broker_data[:last_post] &&
      NaiveDateTime.compare(broker_data[:snoozed_till], NaiveDateTime.utc_now()) == :gt
  end

  def today_snooze_check(broker_data) do
    broker_data[:snoozed] && broker_data[:last_post] &&
      NaiveDateTime.compare(broker_data[:snoozed_till], NaiveDateTime.utc_now()) in [:eq, :gt] &&
      NaiveDateTime.compare(broker_data[:snoozed_till], Time.get_day_beginnning_and_end_time() |> elem(1)) in [:eq, :lt]
  end

  def snooze_check(broker_data) do
    broker_data[:last_post] && broker_data[:snoozed_till_epoch]
  end

  def remove_all_assignments(broker_id) do
    broker_id |> AssignedBrokers.remove_all_assignments()
  end

  def fetch_or_create_sendbird_channel(broker_id, broker_uuid, broker_name, employee_id, employee_uuid, employee_vertical_id) do
    payload = create_manager_broker_sendbird_channel_payload(broker_uuid, employee_uuid, employee_vertical_id)
    is_channel_exists = ExternalApiHelper.is_channel_already_exists(payload["channel_url"])

    meta_data = %{
      "metadata" => %{
        "broker_name" => broker_name
      },
      "upsert" => true
    }

    case is_channel_exists do
      false ->
        channel_url = ExternalApiHelper.create_sendbird_channel(payload)

        if not is_nil(channel_url) do
          save_channel_url(broker_id, employee_id, channel_url)
          create_sendbird_channel_meta_data(broker_uuid, channel_url, employee_uuid, meta_data)
          {:ok, Map.merge(meta_data, %{"channel_url" => channel_url})}
        else
          error_msg = "Error in creating sendbird channel for broker uuid: #{broker_uuid} and employee uuid : #{employee_uuid}"
          send_notification_on_slack(error_msg)
          {:error, "Failed to create channel"}
        end

      true ->
        channel_url = payload["channel_url"]
        # If the employee is not in the channel have to replace it with the existing one

        with %AssignedBrokers{} = _assigned_brokers <- save_channel_url(broker_id, employee_id, channel_url) do
          members = ExternalApiHelper.fetch_users_in_sendbird_channel(channel_url)
          current_user_ids = Enum.map(members, fn member -> member["user_id"] end)

          if(ExternalApiHelper.is_user_already_exist_in_channel(channel_url, employee_uuid) == false) do
            remove_payload = %{"user_ids" => current_user_ids}
            ExternalApiHelper.remove_user_from_channel(remove_payload, channel_url)

            add_payload = %{"user_ids" => [broker_uuid, employee_uuid]}
            ExternalApiHelper.add_user_to_channel(add_payload, channel_url)
          end

          {:ok, Map.merge(meta_data, %{"channel_url" => channel_url})}
        else
          nil -> {:error, "You are not authorized to take this action!"}
        end
    end
  end

  def create_manager_broker_sendbird_channel_payload(broker_uuid, employee_uuid, employee_vertical_id) do
    vertical_identifier = EmployeeVertical.get_vertical_by_id(employee_vertical_id)["identifier"]

    %{
      "user_ids" => [broker_uuid, employee_uuid],
      "name" => EmployeeCredential.get_manager_name_based_on_vertical(employee_vertical_id),
      "channel_url" => "#{vertical_identifier}_broker_uuid_#{broker_uuid}"
    }
  end

  ## Private Functions

  defp create_sendbird_channel_meta_data(broker_uuid, channel_url, employee_uuid, meta_data) do
    updated_channel_url = ExternalApiHelper.create_sendbird_channel_meta_data(meta_data, channel_url)

    if is_nil(updated_channel_url) do
      error_msg = "Error in updating sendbird metadata for broker uuid: #{broker_uuid} and employee uuid : #{employee_uuid}"
      send_notification_on_slack(error_msg)
    end
  end

  defp send_notification_on_slack(err_msg) do
    channel = ApplicationHelper.get_slack_channel()
    ApplicationHelper.notify_on_slack(err_msg, channel)
  end

  defp save_channel_url(broker_id, employee_id, channel_url) do
    with %AssignedBrokers{} = assigned_broker <- Repo.get_by(AssignedBrokers, employees_credentials_id: employee_id, broker_id: broker_id, active: true) do
      AssignedBrokers.changeset(assigned_broker, %{"channel_url" => channel_url}) |> Repo.update!()
    else
      nil -> nil
    end
  end

  defp filter_organization_brokers(brokers_data, org_uuid) do
    brokers_data
    |> Enum.filter(&(&1[:org_uuid] == org_uuid))
  end

  defp add_broker_analytics(brokers_data, org_id) do
    brokers_data
    |> Enum.map(fn broker_data ->
      rental_posts = Posts.fetch_org_user_rental_posts(org_id, broker_data[:user_id])
      {active_rental_posts, _} = rental_posts |> Posts.segregate_active_inactive_posts()
      resale_posts = Posts.fetch_org_user_resale_posts(org_id, broker_data[:user_id])
      {active_resale_posts, _} = resale_posts |> Posts.segregate_active_inactive_posts()

      broker_data
      |> Map.merge(%{
        total_posts: length(rental_posts) + length(resale_posts),
        active_rental_posts: length(active_rental_posts),
        active_resale_posts: length(active_resale_posts),
        total_active_posts: length(active_rental_posts) + length(active_resale_posts)
      })
    end)
  end

  defp add_organization_analytics(org_data, org) do
    Enum.reduce(org_data, %{}, fn {org_name, org_data_map}, acc ->
      put_in(acc, [org_name], org_data_map |> Map.merge(org_analytics(org_data_map, org)))
    end)
  end

  defp org_analytics(org_data_map, org) do
    org_analytics = %{
      total_posts: 0,
      active_resale_posts: 0,
      active_rental_posts: 0,
      total_active_posts: 0
    }

    org_analytics =
      org_data_map[:brokers_data]
      |> Enum.reduce(org_analytics, fn broker_data, acc ->
        acc = put_in(acc, [:total_posts], acc[:total_posts] + broker_data[:total_posts])
        acc = put_in(acc, [:active_resale_posts], acc[:active_resale_posts] + broker_data[:active_resale_posts])
        acc = put_in(acc, [:active_rental_posts], acc[:active_rental_posts] + broker_data[:active_rental_posts])
        put_in(acc, [:total_active_posts], acc[:total_active_posts] + broker_data[:total_active_posts])
      end)

    assigned_on_epoch = org_data_map[:brokers_data] |> Enum.map(& &1[:assigned_on_epoch]) |> Enum.min()

    org_analytics
    |> Map.merge(%{
      inserted_at_epoch: org.inserted_at |> Time.naive_to_epoch(),
      assigned_on_epoch: assigned_on_epoch
    })
  end

  defp process_organization_response(org_data) do
    Enum.reduce(org_data, %{}, fn {org_name, org_data_map}, acc ->
      org_data_map = put_in(org_data_map, [:org_name], org_name)
      acc |> Map.merge(org_data_map)
    end)
  end

  defp add_organization_polygon_info(data) do
    data
    |> Enum.map(fn org_data ->
      {operating_city, polygon_id} =
        case Organization.fetch_poly_data_from_org(org_data[:id]) do
          %{operating_city: operating_city, polygon_id: polygon_id} -> {operating_city, polygon_id}
          _ -> {nil, nil}
        end

      org_data
      |> Map.merge(%{
        locality: polygon_id && Polygon.fetch_from_id(polygon_id).name,
        city: operating_city && ApplicationHelper.get_city_name_from_id(operating_city)
      })
    end)
  end

  defp group_dashboard_data(data) do
    data
    |> Enum.group_by(& &1[:org_uuid])
  end

  defp sort_organization_wise_brokers(data) do
    Enum.reduce(data, %{}, fn {_org_uuid, brokers_list}, acc ->
      {snoozed_brokers_list, remaining_brokers_list} = Enum.reject(brokers_list, & &1[:is_marked_lost]) |> Enum.split_with(&snooze_check(&1))

      {past_snoozed_brokers_list, today_snoozed_brokers_list, future_snoozed_brokers_list} = segregate_snooozed_brokers(snoozed_brokers_list) |> sort_snoozed_brokers()

      {inactive_brokers_list, active_brokers_list} = remaining_brokers_list |> Enum.split_with(& &1[:last_post]) |> sort_remaining_brokers()

      org_data = %{
        brokers_data:
          past_snoozed_brokers_list ++
            today_snoozed_brokers_list ++ inactive_brokers_list ++ future_snoozed_brokers_list ++ active_brokers_list
      }

      org_name = brokers_list |> List.first() |> (& &1.org_name).()
      put_in(acc, [org_name], org_data)
    end)
  end

  defp filter_organization(data) do
    data
    |> Enum.reject(fn {_org_name, org_data} ->
      brokers_data = org_data[:brokers_data]
      Enum.count(brokers_data, &(&1[:last_post] == false)) == length(brokers_data)
    end)
  end

  defp sort_organization(data) do
    {snoozed_org, inactive_org} = data |> split_organizations()
    {past_snoozed_org, today_snoozed_org, future_snoozed_org} = snoozed_org |> split_snoozed_organizations()

    inactive_org =
      inactive_org
      |> Enum.sort_by(fn {_org_name, org_data} -> sort_organization_on_latest_post(org_data) end, &>=/2)
      |> Enum.map(fn {org_name, org_data} ->
        org_data
        |> Map.merge(%{
          org_name: org_name
        })
      end)

    sort_snoozed_organization(past_snoozed_org) ++
      sort_snoozed_organization(today_snoozed_org) ++ inactive_org ++ sort_snoozed_organization(future_snoozed_org)
  end

  defp split_organizations(data) do
    data
    |> Enum.split_with(fn {_org_name, org_data} -> org_data[:brokers_data] |> List.first() |> snooze_check() end)
  end

  defp split_snoozed_organizations(snoozed_org) do
    {today_snoozed_org, remaining_snoozed_org} =
      snoozed_org
      |> Enum.split_with(fn {_org_name, org_data} -> org_data[:brokers_data] |> List.first() |> today_snooze_check() end)

    {future_snoozed_org, past_snoozed_org} =
      remaining_snoozed_org
      |> Enum.split_with(fn {_org_name, org_data} ->
        org_data[:brokers_data] |> List.first() |> future_snooze_check()
      end)

    {past_snoozed_org, today_snoozed_org, future_snoozed_org}
  end

  defp sort_organization_on_snooze(org_data) do
    (org_data[:brokers_data] |> List.first())[:snoozed_till_epoch]
  end

  defp sort_organization_on_latest_post(org_data) do
    (org_data[:brokers_data] |> List.last())[:last_post_days]
  end

  defp sort_snoozed_organization(snoozed_org) do
    snoozed_org
    |> Enum.sort_by(fn {_org_name, org_data} -> sort_organization_on_snooze(org_data) end)
    |> Enum.map(fn {org_name, org_data} ->
      org_data
      |> Map.merge(%{
        org_name: org_name
      })
    end)
  end

  defp process_all_unassigned_response(data) do
    data
    |> Enum.map(fn {_org_uuid, brokers_list} ->
      broker = brokers_list |> List.first()

      %{
        unassigned_brokers_data: brokers_list,
        org_name: broker[:org_name],
        org_uuid: broker[:org_uuid],
        firm_address: broker[:firm_address],
        locality: broker[:polygon_id] && Polygon.fetch_from_id(broker[:polygon_id]).name,
        city: broker[:operating_city] && ApplicationHelper.get_city_name_from_id(broker[:operating_city])
      }
    end)
  end
end
