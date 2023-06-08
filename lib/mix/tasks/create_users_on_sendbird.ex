defmodule Mix.Tasks.CreateUsersOnSendbird do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.RegisterUserOnSendbird

  @shortdoc "Create users on sendbird"

  def run(_) do
    Mix.Task.run("app.start", [])
    create_users_on_sendbird()
  end

  defp create_users_on_sendbird() do
    Credential
    |> where([cred], cred.active == ^true)
    |> Repo.all()
    |> Enum.each(fn cred ->
      RegisterUserOnSendbird.perform(Credential.get_sendbird_payload(cred))
      Process.sleep(500)
    end)
  end
end
