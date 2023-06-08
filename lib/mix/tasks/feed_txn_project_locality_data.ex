defmodule Mix.Tasks.FeedTxnProjectLocalityData do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Repo
  alias BnApis.FeedTransactions.FeedTransaction
  alias BnApis.FeedTransactions.FeedTransactionProject

  @shortdoc "feed transactions project locality data"
  def run(_) do
    Mix.Task.run("app.start", [])
    populate_feed_txn_project_locality_data()
  end

  def get_txn_data(feed_project_id) do
    FeedTransaction
    |> where(feed_project_id: ^feed_project_id)
    |> Repo.all()
    |> List.last()
  end

  def populate_locality(project) do
    if not is_nil(project) do
      feed_project_id = project.feed_project_id
      txn = get_txn_data(feed_project_id)

      if not is_nil(txn) do
        feed_locality_id = txn.feed_locality_id
        feed_locality_name = txn.feed_locality_name
        full_name = "#{project.feed_project_name}, #{txn.feed_locality_name}"

        attrs = %{
          "feed_locality_id" => feed_locality_id,
          "feed_locality_name" => feed_locality_name,
          "full_name" => full_name
        }

        project
        |> FeedTransactionProject.changeset(attrs)
        |> Repo.update()

        IO.puts(full_name)
      end
    end
  end

  def populate_feed_txn_project_locality_data() do
    FeedTransactionProject
    |> where([p], is_nil(p.full_name))
    |> Repo.all()
    |> Enum.each(fn p ->
      p |> populate_locality()
    end)
  end
end
