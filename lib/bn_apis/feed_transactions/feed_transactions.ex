defmodule BnApis.FeedTransactions do
  @moduledoc """
  The FeedTransactions context.
  """

  import Ecto.Query, warn: false
  alias BnApis.Repo

  alias BnApis.Helpers.Time

  alias BnApis.FeedTransactions.FeedTransaction
  alias BnApis.FeedTransactions.FeedTransactionLocality
  alias BnApis.FeedTransactions.FeedTransactionProject

  def filter_transactions(params) do
    {query, content_query, page, size} = FeedTransaction.filter_query(params)

    feed_transactions =
      content_query
      |> Repo.all()

    total_count =
      query
      |> Repo.aggregate(:count, :id)

    has_more_feed_transactions = page < Float.ceil(total_count / size)
    {feed_transactions, total_count, has_more_feed_transactions}
  end

  def create_transaction(attrs \\ %{}) do
    attrs =
      if attrs["registration_date"] |> is_nil() do
        attrs
      else
        attrs |> Map.merge(%{"registration_date" => attrs["registration_date"] |> Time.epoch_to_naive()})
      end

    %FeedTransaction{}
    |> FeedTransaction.changeset(attrs)
    |> Repo.insert()
  end

  def create_transactions(feed_transactions \\ []) do
    feed_transactions
    |> create_location_structs()
    |> (&Repo.insert_all(FeedTransactionLocality, &1, on_conflict: :nothing)).()

    feed_transactions
    |> create_project_structs()
    |> (&Repo.insert_all(FeedTransactionProject, &1, on_conflict: :nothing)).()

    feed_transactions
    |> create_structs()
    |> (&Repo.insert_all(FeedTransaction, &1, on_conflict: :nothing)).()
  end

  def create_or_update_transactions(feed_transactions \\ []) do
    feed_transactions
    |> create_location_structs()
    |> Enum.each(fn location_struct ->
      (Repo.get_by(FeedTransactionLocality, feed_locality_id: location_struct[:feed_locality_id]) ||
         %FeedTransactionLocality{})
      |> FeedTransactionLocality.changeset(location_struct)
      |> Repo.insert_or_update()
    end)

    feed_transactions
    |> create_project_structs()
    |> Enum.each(fn project_struct ->
      (Repo.get_by(FeedTransactionProject, feed_project_id: project_struct[:feed_project_id]) ||
         %FeedTransactionProject{})
      |> FeedTransactionProject.changeset(project_struct)
      |> Repo.insert_or_update()
    end)

    feed_transactions
    |> create_structs()
    |> Enum.each(fn transaction_struct ->
      (Repo.get_by(FeedTransaction, comps_id: transaction_struct[:comps_id]) || %FeedTransaction{})
      |> FeedTransaction.changeset(transaction_struct)
      |> Repo.insert_or_update()
    end)

    {length(feed_transactions)}
  end

  def create_structs(feed_transactions) do
    feed_transactions
    |> Enum.map(fn transaction ->
      transaction =
        if transaction["registration_date"] |> is_nil() do
          transaction
        else
          transaction |> Map.merge(%{"registration_date" => transaction["registration_date"] |> Time.epoch_to_naive()})
        end

      transaction =
        if transaction["consideration"] |> is_nil() do
          transaction
        else
          transaction |> Map.merge(%{"consideration" => Float.parse(transaction["consideration"]) |> elem(0)})
        end

      transaction =
        if transaction["converted_area"] |> is_nil() do
          transaction
        else
          transaction |> Map.merge(%{"converted_area" => Float.parse(transaction["converted_area"]) |> elem(0)})
        end

      %{
        area_type: transaction["area_type"],
        comps_id: transaction["comps_id"],
        consideration: transaction["consideration"],
        converted_area: transaction["converted_area"],
        floor: transaction["floor"],
        feed_locality_id: transaction["feed_locality_id"],
        feed_locality_name: transaction["feed_locality_name"],
        feed_project_name: transaction["feed_project_name"],
        feed_project_id: transaction["feed_project_id"],
        registration_date: transaction["registration_date"],
        rent_duration: transaction["rent_duration"],
        tower: transaction["tower"],
        transaction_type: transaction["transaction_type"],
        wing: transaction["wing"],
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        propstack_city_id: transaction["city_id"],
        original_data: transaction["original_data"]
      }
    end)
  end

  def create_location_structs(feed_transactions) do
    feed_transactions
    |> Enum.map(fn transaction ->
      %{
        feed_locality_id: transaction["feed_locality_id"],
        feed_locality_name: transaction["feed_locality_name"],
        propstack_city_id: transaction["city_id"],
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
  end

  def create_project_structs(feed_transactions) do
    feed_transactions
    |> Enum.map(fn transaction ->
      %{
        feed_project_id: transaction["feed_project_id"],
        feed_project_name: transaction["feed_project_name"],
        feed_locality_id: transaction["feed_locality_id"],
        feed_locality_name: transaction["feed_locality_name"],
        full_name: "#{transaction["feed_project_name"]}, #{transaction["feed_locality_name"]}",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }
    end)
  end

  def search_entities(params) do
    city_id = params["city_id"]

    search_text =
      cond do
        not is_nil(params["q"]) ->
          params["q"]

        true ->
          ""
      end

    localities =
      FeedTransactionLocality.search_locality_query(search_text, city_id)
      |> Repo.all()

    projects =
      FeedTransactionProject.search_project_query(search_text, city_id)
      |> Repo.all()

    localities ++ projects
  end
end
