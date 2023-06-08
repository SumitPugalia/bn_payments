defmodule Mix.Tasks.DeleteDsaTestLeads do
  use Mix.Task
  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.Organizations.Broker
  import Ecto.Query

  def run(_) do
    Mix.Task.run("app.start", [])
    delete_dsa_test_leads()
  end

  defp delete_dsa_test_leads() do
    Lead
    |> join(:inner, [l], b in Broker, on: b.id == l.broker_id)
    |> where([l, b], b.role_type_id == 2)
    |> Repo.all()
    |> Enum.each(fn lead ->
      lead |> Lead.changeset(%{"active" => false}) |> Repo.update!()
    end)
  end
end
