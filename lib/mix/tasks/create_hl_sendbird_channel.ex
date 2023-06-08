defmodule Mix.Tasks.CreateHlSendbirdChannel do
  use Mix.Task

  alias BnApis.Repo
  alias BnApis.Homeloan.Lead
  alias BnApis.CreateHLSendbirdChannel

  @shortdoc "Create homeloan lead channel between broker and employee on sendbird"

  def run(_) do
    Mix.Task.run("app.start", [])
    create_channel_on_sendbird()
  end

  defp create_channel_on_sendbird() do
    Lead
    |> Repo.all()
    |> Enum.each(fn lead ->
      CreateHLSendbirdChannel.perform(lead.id)
      Process.sleep(500)
    end)
  end
end
