defmodule BnApis.CreateHLSendbirdChannel do
  import Ecto.Query
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Homeloan.Lead
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Organizations.Broker

  @max_retries 5

  def perform(lead_id), do: perform(lead_id, @max_retries)
  def perform(_, 0), do: :ignore
  def perform(lead_id, nil), do: perform(lead_id, @max_retries)

  def perform(lead_id, retry) do
    try do
      lead = Repo.get_by(Lead, id: lead_id)
      lead = lead |> Repo.preload([:employee_credentials, :broker, broker: [:credentials]])

      if not is_nil(lead.employee_credentials_id) do
        payload = create_hl_sendbird_channel_payload(lead)
        is_channel_exists = ExternalApiHelper.is_channel_already_exists(payload["channel_url"])

        case is_channel_exists do
          false ->
            channel_url = ExternalApiHelper.create_sendbird_channel(payload)

            if not is_nil(channel_url) do
              # create metadata for the channel
              meta_data = %{
                "metadata" => %{
                  "call_through" => "s2c",
                  "lead_id" => "#{lead_id}",
                  "call_with" => "hl_agent"
                },
                "upsert" => true
              }

              ExternalApiHelper.create_sendbird_channel_meta_data(meta_data, channel_url)
              save_channel_url(lead, channel_url)
            end

          true ->
            save_channel_url(lead, payload["channel_url"])
        end
      end
    rescue
      err ->
        channel = ApplicationHelper.get_slack_channel()
        retry_count = @max_retries - retry + 1

        ApplicationHelper.notify_on_slack(
          "Error in creating sendbird channel for hl_lead_id: #{lead_id}............#{Exception.message(err)}...........retry_count:#{retry_count}",
          channel
        )

        Exq.enqueue_in(Exq, "sendbird", retry_count * 10, BnApis.CreateHLSendbirdChannel, [lead_id, retry - 1])
    end
  end

  def create_hl_sendbird_channel_payload(lead) do
    broker_cred = Credential.get_credential_from_broker_id(lead.broker_id)

    %{
      "user_ids" => [lead.employee_credentials.uuid, broker_cred.uuid],
      "name" => "#{lead.name}" <> " " <> "#{lead.id}",
      "channel_url" => "hl_#{lead.id}"
    }
  end

  defp save_channel_url(lead, channel_url) do
    Lead.changeset(lead, %{"channel_url" => channel_url}) |> Repo.update!()
  end

  # cron to create channel which were not successfully created
  def perform_cron() do
    Lead
    |> where([l], is_nil(l.channel_url) and not is_nil(l.employee_credentials_id))
    |> join(:inner, [l], b in Broker, on: l.broker_id == b.id)
    |> join(:inner, [l, b], c in Credential, on: c.broker_id == b.id)
    |> where([l, b, c], c.active == true)
    |> Repo.all()
    |> Enum.each(fn lead ->
      perform(lead.id)
    end)
  end
end
