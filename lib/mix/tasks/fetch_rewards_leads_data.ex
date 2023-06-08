defmodule Mix.Tasks.FetchRewardsLeadsData do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.Status
  alias BnApis.Accounts.Credential

  @shortdoc "Get rewards leads latest data"

  def run(_) do
    Mix.Task.run("app.start", [])
    create_rewards_leads()
  end

  def create_rewards_leads() do
    min_id = Repo.one(from(r in RewardsLead, select: min(r.id)))
    max_id = Repo.one(from(r in RewardsLead, select: max(r.id)))

    size = 50

    no_of_loop = ((max_id - min_id + 1) / size) |> Float.ceil() |> Kernel.round()

    1..no_of_loop
    |> Task.async_stream(
      fn page_no ->
        min_entry_id = (page_no - 1) * size
        max_entry_id = min_entry_id + size

        rewards_leads =
          Repo.all(
            from(r in RewardsLead,
              where:
                fragment(
                  "(? > ? and ? <= ?)",
                  r.id,
                  ^min_entry_id,
                  r.id,
                  ^max_entry_id
                ),
              limit: ^size,
              select: r,
              order_by: r.id
            )
          )
          |> Repo.preload([
            :story,
            :developer_poc_credential,
            :broker,
            :latest_status
          ])

        write_in_csv(rewards_leads)
      end,
      ordered: false,
      timeout: 50000
    )
    |> Stream.run()
  end

  def write_in_csv(rewards_leads) do
    rewards_csv =
      File.open!("rewards_leads.csv", [
        :write,
        :utf8
      ])

    csv_entry = [
      "lead_id",
      "lead_name",
      "story_name",
      "broker_name",
      "poc_credential_name",
      "poc_credential_number",
      "organization_name",
      "status"
    ]

    [csv_entry]
    |> IO.inspect()
    |> CSV.encode()
    |> Enum.each(&IO.write(rewards_csv, &1))

    rewards_leads
    |> Enum.each(fn lead ->
      lead_name = lead.name
      lead_id = lead.id

      story_name = lead.story.name

      broker_id = lead.broker_id
      broker_name = lead.broker.name

      status_id = lead.latest_status.status_id
      status_name = Status.status_details(status_id)["display_name"]

      developer_poc_credential_name = lead.developer_poc_credential.name

      developer_poc_credential_number = lead.developer_poc_credential.phone_number

      credential = Credential.get_credential_from_broker_id(broker_id)
      credential = credential |> Repo.preload(:organization)
      organization_name = credential.organization.name

      csv_entry = [
        lead_id,
        lead_name,
        story_name,
        broker_name,
        developer_poc_credential_name,
        developer_poc_credential_number,
        organization_name,
        status_name
      ]

      [csv_entry]
      |> IO.inspect()
      |> CSV.encode()
      |> Enum.each(&IO.write(rewards_csv, &1))
    end)
  end
end
