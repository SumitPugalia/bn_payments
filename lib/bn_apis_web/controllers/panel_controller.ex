defmodule BnApisWeb.PanelController do
  use BnApisWeb, :controller
  alias BnApis.Helpers.ApplicationHelper

  action_fallback(BnApisWeb.FallbackController)

  @doc """
    Runs given query on BN database and provides results
    
    @param {string} sql [sql query]
    @param {string} key [for validating request]

    returns {
      "results": [
        [columns],
        [row1],
        [row2],
        ...
      ]
    }
  """

  def query(conn, params) do
    with {:ok, _} <- validate_key(params["key"]),
         {:ok, response} <-
           Ecto.Adapters.SQL.query(BnApis.Repo, params["sql"], []) do
      results = [response.columns] ++ response.rows

      conn
      |> put_status(:ok)
      |> json(%{results: results})
    end
  end

  defp validate_key(key) do
    if key == ApplicationHelper.db_query_key() do
      {:ok, ""}
    else
      {:unauthorized, "Wrong db query key"}
    end
  end
end
