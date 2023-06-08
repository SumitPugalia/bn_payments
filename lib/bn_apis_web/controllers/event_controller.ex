defmodule BnApisWeb.EventController do
  use BnApisWeb, :controller

  alias BnApis.Helpers.Connection

  def create(conn, params) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)
    params = params |> process_params(logged_in_user)
    params |> BnApis.Events.Event.create_event()
    conn |> put_status(:ok) |> json(%{message: "Successfully Created"})
  end

  defp process_params(params, logged_in_user) do
    params
    |> Map.merge(%{
      "user_id" => logged_in_user[:user_id],
      "type" => params["type"] |> String.downcase() |> String.replace(" ", "_"),
      "action" => params["action"] |> String.downcase() |> String.replace(" ", "_")
    })
  end
end
