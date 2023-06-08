defmodule Mix.Tasks.RefreshSimilarTransactionBuildingData do
  use Mix.Task
  alias BnApis.Repo
  alias Ecto.Adapters.SQL
  alias BnApis.Transactions.{DuplicateBuildingTemp, Building}

  @shortdoc "Refreshes similar building data with approximate count"
  def run(_) do
    Mix.Task.run("app.start", [])
    # Truncate duplicate_buildings_temp
    SQL.query(Repo, "TRUNCATE table duplicate_buildings_temp restart identity", [])
    count = Building |> Repo.aggregate(:count, :id)
    each_interation = 5000
    interations = Float.ceil(count / each_interation) |> round()

    Enum.each(0..interations, fn index ->
      {:ok, %{rows: rows}} = SQL.query(Repo, similar_buildings_sql_query(), [each_interation, index * each_interation], timeout: 150_000)

      rows |> Enum.each(&create_record/1)
    end)
  end

  def similar_buildings_sql_query() do
    """
    WITH
    a as (
      select tb1.id, count(*), array_agg(tb2.id order by tb2.id) as ids
      from (select * from transactions_buildings limit $1 offset $2) tb1
      JOIN (select * from transactions_buildings limit $1 offset $2) tb2
      ON similarity(tb1.name, tb2.name) > 0.8
      group by tb1.id
      order by count(*) desc
    ),
    b as (
      select array(select unnest(ids) order by 1) as sorted_arr, count(*)
      from a
      where count > 1
      group by sorted_arr
    ),
    c as (
    select *, (select count(*) from (select unnest(sorted_arr)) n) as count_new, (select name from transactions_buildings where id in (select unnest(sorted_arr)) limit 1) as name from b
    )
    select sorted_arr, count, name from c where count = count_new order by count_new desc;
    """
  end

  def create_record([_arr_agg, count, name]) do
    params = %{
      name: name |> String.trim(),
      count: count
    }

    DuplicateBuildingTemp.changeset(params) |> Repo.insert()
  end
end
