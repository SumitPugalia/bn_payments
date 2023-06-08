defmodule BnApisWeb.V1.CommonController do
  use BnApisWeb, :controller
  alias BnApis.Helpers.Common
  alias BnApis.Helpers.Connection
  alias BnApis.Helpers.ApplicationHelper

  action_fallback BnApisWeb.FallbackController

  def get_metadata(conn, _params) do
    with {:ok, data} <- Common.get_meta_data() do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def search_entities_for_employee(conn, %{"query" => query, "entity_type" => entity_type}) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    with {:ok, data} <- Common.search_entities_for_employee(logged_in_user, query, entity_type) do
      conn
      |> put_status(:ok)
      |> json(data)
    end
  end

  def generate_random_token(conn, _params) do
    token = Ecto.UUID.generate()

    conn
    |> put_status(:ok)
    |> json(%{"token" => token})
  end

  def notify_on_slack(conn, %{"data" => data, "context" => context}) do
    text = Enum.reduce(data, "-------------------------------Query-----------------------------\n", fn {k, v}, acc -> acc <> "#{k}: #{v}" <> "\n" end)
    ApplicationHelper.post_message_on_slack_channel(text, context)
    conn |> put_status(:ok) |> json(%{message: "Successfully posted on slack"})
  end
end
