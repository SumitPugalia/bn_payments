defmodule BnApisWeb.ProjectView do
  use BnApisWeb, :view
  alias BnApisWeb.ProjectView
  alias BnApis.Helpers.Time

  def render("index.json", %{projects: projects}) do
    %{data: render_many(projects, ProjectView, "project.json")}
  end

  def render("show.json", %{project: project}) do
    render_one(project, ProjectView, "project.json")
  end

  def render("details.json", %{
        project: project,
        recently_called_sales_person_id: sales_person_id
      }) do
    render_one(project, ProjectView, "project.json", %{sales_person_id: sales_person_id})
  end

  def render("all_call_logs.json", %{call_logs: call_logs}) do
    %{
      project_call_logs: render_many(call_logs, ProjectView, "call_log.json", as: :call_log)
    }
  end

  def render("project.json", %{project: project, sales_person_id: sales_person_id}) do
    %{
      uuid: project.uuid,
      project_name: project.name,
      display_address: project.display_address,
      sales_team: render_many(project.sales_persons, ProjectView, "sales_person.json", %{sales_person_id: sales_person_id})
    }
  end

  def render("sales_person.json", %{project: sales_person, sales_person_id: sales_person_id}) do
    %{
      uuid: sales_person.uuid,
      name: sales_person.name,
      designation: sales_person.designation,
      phone_number: sales_person.phone_number,
      recent: sales_person_id == sales_person.id
    }
  end

  def render("call_log.json", %{call_log: call_log}) do
    %{
      uuid: call_log.uuid,
      timestamp: call_log.timestamp |> Time.naive_to_epoch(),
      project_name: call_log.sales_person.project.name,
      sales_person_name: call_log.sales_person.name,
      sales_person_uuid: call_log.sales_person.uuid,
      phone_number: call_log.sales_person.phone_number,
      designation: call_log.sales_person.designation
    }
  end
end
