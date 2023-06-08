defmodule BnApisWeb.FeedTransactionView do
  use BnApisWeb, :view
  alias BnApisWeb.FeedTransactionView
  alias BnApis.Helpers.Time
  alias BnApis.FeedTransactions.FeedTransactionLocality

  def render("index.json", %{
        feed_transactions: feed_transactions,
        total_count: total_count,
        has_more_feed_transactions: has_more_feed_transactions
      }) do
    %{
      data: render_many(feed_transactions, FeedTransactionView, "feed_transaction.json"),
      total_count: total_count,
      has_more_feed_transactions: has_more_feed_transactions,
      has_more: has_more_feed_transactions
    }
  end

  def render("feed_transactions.json", %{feed_transactions: feed_transactions}) do
    %{data: render_many(feed_transactions, FeedTransactionView, "feed_transaction.json")}
  end

  def render("feed_transaction.json", %{feed_transaction: feed_transaction}) do
    %{
      id: feed_transaction.id,
      comps_id: feed_transaction.comps_id,
      floor: feed_transaction.floor,
      transaction_type: feed_transaction.transaction_type,
      registration_date: feed_transaction.registration_date |> Time.naive_to_epoch(),
      feed_locality_id: feed_transaction.feed_locality_id,
      feed_locality_name: feed_transaction.feed_locality_name,
      feed_project_id: feed_transaction.feed_project_id,
      feed_project_name: feed_transaction.feed_project_name,
      consideration: feed_transaction.consideration,
      converted_area: feed_transaction.converted_area,
      rent_duration: feed_transaction.rent_duration,
      area_type: "#{feed_transaction.area_type} area",
      show_area_type: if(feed_transaction.propstack_city_id == 2, do: true, else: false),
      tower: feed_transaction.tower,
      wing: feed_transaction.wing,
      city_id: feed_transaction.propstack_city_id
    }
  end

  def render("entities.json", %{entities: entities}) do
    %{data: render_many(entities, FeedTransactionView, "entity.json", as: :entity)}
  end

  def render("entity.json", %{entity: entity}) do
    %{
      id: entity.id,
      name: entity.name,
      type: entity.type
    }
  end

  def render("feed_locality.json", %{feed_locality: feed_locality}) do
    FeedTransactionLocality.get_details(feed_locality)
  end

  def render("feed_localities.json", %{feed_localities: feed_localities}) do
    %{data: render_many(feed_localities, FeedTransactionView, "feed_locality.json", as: :feed_locality)}
  end
end
