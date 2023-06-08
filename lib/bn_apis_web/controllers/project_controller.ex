defmodule BnApisWeb.ProjectController do
  use BnApisWeb, :controller

  alias BnApis.Developers
  alias BnApis.Developers.Project

  action_fallback BnApisWeb.FallbackController

  def index(conn, _params) do
    projects = Developers.list_projects()
    render(conn, "index.json", projects: projects)
  end

  def create(conn, %{"project" => project_params}) do
    with {:ok, %Project{} = project} <- Developers.create_project(project_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.project_path(conn, :show, project))
      |> render("show.json", project: project)
    end
  end

  def show(conn, %{"id" => id}) do
    project = Developers.get_project!(id)
    render(conn, "show.json", project: project)
  end

  def update(conn, %{"id" => id, "project" => project_params}) do
    project = Developers.get_project!(id)

    with {:ok, %Project{} = project} <- Developers.update_project(project, project_params) do
      render(conn, "show.json", project: project)
    end
  end

  def delete(conn, %{"id" => id}) do
    project = Developers.get_project!(id)

    with {:ok, %Project{}} <- Developers.delete_project(project) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc """
    Requires Session
    To be used for user autocomplete from projects
  """

  def suggest_projects(conn, %{"q" => search_text, "exclude_project_uuids" => exclude_project_uuids}) do
    search_text = search_text |> String.downcase()
    exclude_project_uuids = if exclude_project_uuids == "", do: [], else: exclude_project_uuids |> Poison.decode!()

    suggestions = Developers.get_suggestions(search_text, exclude_project_uuids)

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def suggest_projects(conn, %{"q" => search_text}) do
    search_text = search_text |> String.downcase()
    suggestions = Developers.get_suggestions(search_text, [])

    conn
    |> put_status(:ok)
    |> json(%{suggestions: suggestions})
  end

  def project_details(conn, %{"project_uuid" => project_uuid}) do
    user_id = conn.assigns[:user]["user_id"]
    project = Developers.get_project_by_uuid(project_uuid)
    recently_called_sales_person_id = Developers.get_user_recent_call_to(user_id)
    render(conn, "details.json", project: project, recently_called_sales_person_id: recently_called_sales_person_id)
  end

  def create_call_log(conn, %{"person_uuid" => person_uuid}) do
    user_id = conn.assigns[:user]["user_id"]

    with {:ok, _call_log} <- Developers.create_sales_call_log(person_uuid, user_id) do
      conn
      |> put_status(:ok)
      |> json(%{message: "Log successfully created!"})
    end
  end

  def get_call_logs(conn, _params) do
    user_id = conn.assigns[:user]["user_id"]
    call_logs = Developers.get_sales_call_logs(user_id)
    render(conn, "all_call_logs.json", call_logs: call_logs)
  end
end
