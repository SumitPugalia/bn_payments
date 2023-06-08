defmodule Mix.Tasks.PopulateEmployeeIdHl do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Homeloan.Lead
  alias BnApis.Repo
  alias BnApis.Organizations.Broker

  @shortdoc "update employee id in hl leads"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_employee_id()
  end

  defp update_employee_id() do
    Lead
    |> where([l], is_nil(l.employee_credentials_id))
    |> Repo.all()
    |> Enum.each(fn lead ->
      broker = Repo.get(Broker, lead.broker_id)
      city_id = if not is_nil(broker), do: broker.operating_city, else: 1
      city_id = if not is_nil(city_id), do: city_id, else: 1
      agent_to_assign = Lead.get_rr_agent_to_assign(city_id)

      changeset =
        Lead.changeset(lead, %{
          employee_credentials_id: agent_to_assign
        })

      Repo.update!(changeset)
    end)
  end
end
