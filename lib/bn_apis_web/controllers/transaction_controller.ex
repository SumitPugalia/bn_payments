defmodule BnApisWeb.TransactionController do
  use BnApisWeb, :controller

  alias BnApis.Transactions
  alias BnApis.Transactions.TransactionData
  # alias BnApis.Helpers.Connection

  action_fallback(BnApisWeb.FallbackController)

  def search_buildings(
        conn,
        _params = %{"q" => _search_text, "locality_uuid" => _locality_uuid}
      ) do
    # Transactions.get_search_suggestions(search_text, locality_uuid)
    buildings = []

    conn
    |> put_status(:ok)
    |> json(%{buildings: buildings})
  end

  def search_buildings(conn, _params = %{"q" => _search_text}) do
    # Transactions.get_search_suggestions(search_text)
    buildings = []

    conn
    |> put_status(:ok)
    |> json(%{buildings: buildings})
  end

  def get_transactions(
        conn,
        params = %{
          "locality_uuid" => _locality_uuid,
          "type" => _type
        }
      ) do
    page = (params["page"] && params["page"] |> String.to_integer()) || 1
    _params = params |> Map.merge(%{"page" => page})

    # Transactions.get_transactions(params)
    transactions = []
    render(conn, "transactions.json", transactions: transactions)
  end

  def transaction_html(conn, %{"transaction_data_id" => transaction_data_id}) do
    with {:ok, %TransactionData{} = transaction} <-
           Transactions.get_transaction_html(transaction_data_id) do
      conn
      |> put_status(:ok)
      |> json(%{html: transaction.doc_html})
    end
  end
end
