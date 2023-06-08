defmodule BnApisWeb.Admin.PriorityStoryController do
  use BnApisWeb, :controller

  alias BnApis.Stories.PriorityStories
  alias BnApis.Helpers.{Connection, Utils}
  alias BnApis.Accounts.EmployeeRole

  action_fallback(BnApisWeb.FallbackController)

  plug :access_check,
       [allowed_roles: [EmployeeRole.super().id, EmployeeRole.admin().id]]
       when action in [:prioritize_story, :delete_priority_story, :list_all_priority_stories, :change_priority_story]

  def prioritize_story(conn, _params = %{"story_id" => story_id, "city_id" => city_id, "priority" => priority}) do
    logged_in_employee_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_employee_user)

    case PriorityStories.prioritize_story(story_id, city_id, priority, user_map) do
      {:ok, _data} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "Story prioritized successfully."})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def delete_priority_story(conn, _params = %{"id" => ps_id}) do
    logged_in_employee_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_employee_user)

    case PriorityStories.delete_priority_story(ps_id, user_map) do
      {:ok, data} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "PriorityStory with id: #{data.id} deleted successfully."})

      {:error, reason} ->
        {:error, reason}
    end
  end

  def list_all_priority_stories(conn, _params) do
    priority_stories = PriorityStories.list_all_priority_stories()

    conn
    |> put_status(:ok)
    |> json(%{"data" => priority_stories})
  end

  def change_priority_story(conn, _params = %{"id" => priority_story_id, "new_story_id" => new_story_id}) do
    logged_in_employee_user = Connection.get_employee_logged_in_user(conn)
    user_map = Utils.get_user_map(logged_in_employee_user)

    case PriorityStories.change_priority_story(priority_story_id, new_story_id, user_map) do
      {:ok, _data} ->
        conn
        |> put_status(:ok)
        |> json(%{"message" => "Priority Story changed successfully."})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp access_check(conn, options) do
    logged_in_user = Connection.get_employee_logged_in_user(conn)

    if logged_in_user.employee_role_id in options[:allowed_roles] do
      conn
    else
      conn
      |> send_resp(401, "Sorry, You are not authorized to take this action!")
      |> halt()
    end
  end
end
