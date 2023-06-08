defmodule BnApis.Campaign.CampaignManager do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Campaign.Schema.Campaign
  alias BnApis.Campaign.Schema.CampaignLeads
  alias BnApis.Organizations.Broker
  alias Ecto.Multi

  def affected_brokers_count(params) do
    query =
      Broker
      |> join(:inner, [b], cred in assoc(b, :credentials))
      |> Broker.filter_brokers_query(params)
      |> select([b], count(b.id, :distinct))

    %{count: Repo.one(query), executed_sql: flatten_sql(query)}
  end

  def affected_brokers_query(params) do
    Broker
    |> join(:inner, [b], cred in assoc(b, :credentials))
    |> Broker.filter_brokers_query(params)
    |> distinct([b], b.id)
    |> select([b], b.id)
  end

  defdelegate update_campaign_stats(campaign_id, broker_id, action), to: CampaignLeads

  def stats_for_nerds(campaign_identifier_list) do
    Campaign
    |> join(:left, [c], assoc(c, :campaign_leads))
    |> where([c, lead], c.campaign_identifier in ^campaign_identifier_list)
    |> select([c, lead], %{
      campaign_identifier: c.campaign_identifier,
      delivered: fragment("SUM(CASE WHEN ? THEN 1 ELSE 0 END)", lead.delivered),
      retries: sum(lead.retries),
      action_taken: fragment("SUM(CASE WHEN ? THEN 1 ELSE 0 END)", lead.action_taken),
      shown: fragment("SUM(CASE WHEN ? THEN 1 ELSE 0 END)", lead.shown),
      sent: fragment("SUM(CASE WHEN ? THEN 1 ELSE 0 END)", lead.sent),
      total: count(lead.id)
    })
    |> group_by([c], c.campaign_identifier)
    |> Repo.all()
  end

  def fetch_all_campaign_with_details(params) do
    page_no = Map.get(params, "p", "1") |> String.to_integer() |> max(1)
    limit = Map.get(params, "limit", "30") |> String.to_integer() |> max(1) |> min(100)
    get_paginated_results(page_no, limit)
  end

  def active_campaign_for_broker(broker_id) do
    now_epoch = DateTime.to_unix(DateTime.utc_now())

    Campaign
    |> join(:left, [c], assoc(c, :campaign_leads))
    |> where([c, cl], c.start_date <= ^now_epoch and c.end_date >= ^now_epoch and cl.broker_id == ^broker_id and cl.shown == false)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def insert_campaign(campaign_identifier, start_date, end_date, campaign_type, data, params) do
    query = affected_brokers_query(params)

    campaign_query = %{
      data: data,
      type: campaign_type,
      campaign_identifier: campaign_identifier,
      start_date: start_date,
      end_date: end_date,
      executed_sql: flatten_sql(query),
      active: true
    }

    Multi.new()
    |> Multi.insert(:campaign, Campaign.new(campaign_query))
    |> Multi.run(:cache, fn repo, %{campaign: campaign} ->
      query
      |> Repo.stream()
      |> Stream.chunk_every(1000)
      |> Stream.each(&insert_campaign_leads(&1, repo, campaign.id))
      |> Stream.run()

      {:ok, 0}
    end)
    |> Repo.transaction()
    |> case do
      {:ok, map} ->
        Exq.enqueue_at(Exq, "campaign", DateTime.from_unix!(map.campaign.start_date), BnApis.Brokers.CampaignNotificationWorker, [map.campaign.id])
        {:ok, map.campaign}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def update_campaign(id, params) do
    campaign = fetch_campaign_by_id(id)

    cond do
      is_nil(campaign) ->
        {:error, "Campaign not found."}

      campaign ->
        campaign
        |> Campaign.changeset(params)
        |> Repo.update()
    end
  end

  def fetch_campaign(id) do
    fetch_campaign_by_id(id)
  end

  ## Private APIs

  defp fetch_campaign_by_id(nil), do: nil
  defp fetch_campaign_by_id(id), do: Campaign |> Repo.get_by(id: id)

  defp get_paginated_results(page_no, limit) do
    offset = (page_no - 1) * limit

    campaigns =
      Campaign
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    campaigns =
      campaigns
      |> Enum.map(& &1.campaign_identifier)
      |> stats_for_nerds()
      |> merge(campaigns)

    next = if length(campaigns) == limit, do: page_no + 1, else: -1

    %{
      "data" => campaigns,
      "next" => next
    }
  end

  defp merge(list1, list2) do
    (list2 ++ list1)
    |> Enum.reduce(%{}, fn element, map ->
      case Map.get(map, element.campaign_identifier) do
        nil ->
          Map.put(map, element.campaign_identifier, element)

        data ->
          data = if is_struct(data), do: Map.from_struct(data), else: data
          Map.put(map, element.campaign_identifier, Enum.into(data, element))
      end
    end)
    |> Enum.map(&(elem(&1, 1) |> Map.drop(~w(__meta__ __struct__ campaign_leads)a)))
    |> Enum.sort(fn a, b -> NaiveDateTime.compare(a.inserted_at, b.inserted_at) == :gt end)
  end

  defp insert_campaign_leads(broker_ids, repo, campaign_id) do
    curr_time = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    map = for id <- broker_ids, do: %{broker_id: id, campaign_id: campaign_id, inserted_at: curr_time, updated_at: curr_time}

    repo.insert_all(CampaignLeads, map)
  end

  defp flatten_sql(query) do
    {query, params} = Repo.to_sql(:all, query)

    params
    |> Enum.with_index(1)
    |> Enum.reduce(query, fn {key, value}, acc -> String.replace(acc, "$#{value}", convert_to_string(key)) end)
    |> String.replace("\"", "")
  end

  defp convert_to_string(value) when is_bitstring(value), do: value
  defp convert_to_string(value), do: inspect(value, charlists: :as_lists)
end
