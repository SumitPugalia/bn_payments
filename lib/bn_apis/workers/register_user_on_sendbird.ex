defmodule BnApis.RegisterUserOnSendbird do
  alias BnApis.Helpers.ExternalApiHelper
  alias BnApis.Accounts.Credential
  alias BnApis.Repo
  alias BnApis.Helpers.ApplicationHelper

  def perform(payload, uuid \\ nil) do
    if not is_nil(uuid) do
      Credential
      |> Repo.get_by(uuid: uuid)
      |> get_user_on_sendbird(uuid, payload)
      |> maybe_create_user_on_sendbird(payload)
    else
      ExternalApiHelper.create_user_on_sendbird(payload)
    end
  end

  def get_user_on_sendbird(_credential = nil, uuid, payload) do
    channel = ApplicationHelper.get_slack_channel()

    ApplicationHelper.notify_on_slack(
      "Issue in registering user on sendbird via worker uuid: #{uuid}, payload:#{Jason.encode!(payload)}",
      channel
    )

    :ok
  end

  def get_user_on_sendbird(%Credential{sendbird_user_id: user_id} = cred, uuid, _payload) when is_nil(user_id) do
    sendbird_user = ExternalApiHelper.get_user_on_sendbird(uuid)

    case sendbird_user do
      {:ok, response} -> update_sendbird_user_id(cred, response["user_id"])
      {:error, _msg} -> {:error, cred}
    end
  end

  def get_user_on_sendbird(_cred, _uuid, _payload), do: :ok

  def maybe_create_user_on_sendbird({:error, cred}, payload) do
    user_id = payload |> ExternalApiHelper.create_user_on_sendbird()
    update_sendbird_user_id(cred, user_id)
  end

  def maybe_create_user_on_sendbird(_result, _payload), do: :ok

  defp update_sendbird_user_id(_cred, nil), do: :ok

  defp update_sendbird_user_id(credential, user_id),
    do: credential |> Credential.changeset(%{"sendbird_user_id" => user_id}) |> Repo.update!()
end
