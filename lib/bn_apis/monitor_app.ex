defmodule BnApis.MonitorApp do
  import Ecto.Query

  alias BnApis.Repo
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.FcmNotification

  def uninstall do
    Credential
    |> where(active: true)
    |> where([c], not is_nil(c.fcm_id))
    # |> where([c], fragment("? < now() - INTERVAL '1 day'", c.last_active_at))
    |> Repo.all()
    |> Enum.each(fn cred ->
      FcmNotification.send_push(cred.fcm_id, %{type: "APP UNINSTALL FCM CHECK"}, cred.id, cred.notification_platform)
    end)
  end

  def remove_tmp_files() do
    # clean .pdf files in pwd
    Path.wildcard("#{File.cwd!()}/*.pdf") |> Enum.each(&File.rm(&1))

    # clean pdf files being generated by pdf generator deps
    Path.wildcard("/tmp/*.pdf") |> Enum.each(&File.rm(&1))
    Path.wildcard("/tmp/*.html") |> Enum.each(&File.rm(&1))
  end
end
