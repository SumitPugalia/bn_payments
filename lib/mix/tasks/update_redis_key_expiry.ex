defmodule Mix.Tasks.UpdateRedisKeyExpiry do
  use Mix.Task
  alias BnApis.Helpers.Redis

  @shortdoc "Set expiry of otp request count"

  def run(_) do
    Mix.Task.run("app.start", [])
    set_app_expiry()
    set_panel_expiry()
  end

  defp set_app_expiry() do
    {:ok, app_keys} = Redis.q(["keys", "*_1_otp_request_count"])
    app_keys |> set_expiry_time()
  end

  defp set_panel_expiry() do
    {:ok, panel_keys} = Redis.q(["keys", "*_2_otp_request_count"])
    panel_keys |> set_expiry_time()
  end

  defp set_expiry_time(keys) do
    keys |> Enum.map(&Redis.q(["expire", &1, 5]))
  end
end
