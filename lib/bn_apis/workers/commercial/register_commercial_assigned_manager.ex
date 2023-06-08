defmodule BnApis.Commercial.RegisterCommercialAssignedManager do
  alias BnApis.Helpers.{ExternalApiHelper, ApplicationHelper}
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Repo

  @max_retries 5

  def perform(_, _, _retry = 0), do: :ignore

  def perform(payload, empl_credentials, retry) do
    sendbird_user_id = ExternalApiHelper.create_user_on_sendbird(payload)
    channel = ApplicationHelper.get_slack_channel()

    case sendbird_user_id do
      nil ->
        retry_count = @max_retries - retry + 1

        ApplicationHelper.notify_on_slack(
          "User Registration failed for user_id:#{payload["user_id"]} ,retry_count:#{retry_count}",
          channel
        )

        Exq.enqueue_in(
          Exq,
          "commercial_sendbird",
          retry_count * 10,
          BnApis.Commercial.RegisterCommercialAssignedManager,
          [payload, empl_credentials, retry - 1]
        )

      sendbird_user_id ->
        EmployeeCredential.changeset(empl_credentials, %{"sendbird_user_id" => sendbird_user_id}) |> Repo.update()
    end
  end
end
