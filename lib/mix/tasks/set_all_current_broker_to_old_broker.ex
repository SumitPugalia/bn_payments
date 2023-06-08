defmodule Mix.Tasks.SetAllCurrentBrokerToOldBroker do
  use Mix.Task
  import Ecto.Query
  alias BnApis.Accounts.Credential
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Homeloan.Lead
  alias BnApis.Developers.SiteVisit
  alias BnApis.Cabs.BookingRequest
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Stories.Schema.Invoice

  @shortdoc "set old_broker_id to current broker_id and it's org"
  def run(_) do
    Mix.Task.run("app.start", [])

    SiteVisit
    |> join(:inner, [s], c in Credential, on: c.id == s.visited_by_id)
    |> where([s], is_nil(s.old_organization_id) and is_nil(s.old_visited_by_id))
    |> update([s, c], set: [old_visited_by_id: s.visited_by_id, old_organization_id: c.organization_id])
    |> BnApis.Repo.update_all([])

    IO.inspect(SiteVisit, label: "migrated")

    for schema <- [BookingRewardsLead, Invoice, Lead, BookingRequest, BillingCompany] do
      schema
      |> join(:inner, [s], c in Credential, on: c.broker_id == s.broker_id)
      |> where([s], is_nil(s.old_broker_id) and is_nil(s.old_organization_id))
      |> update([s, c], set: [old_broker_id: s.broker_id, old_organization_id: c.organization_id])
      |> BnApis.Repo.update_all([])

      IO.inspect(schema, label: "migrated")
    end
  end
end
