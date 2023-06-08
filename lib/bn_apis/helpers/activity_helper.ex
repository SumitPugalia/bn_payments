defmodule BnApis.Helpers.ActivityHelper do
  alias BnApis.Helpers.ActivityHelper
  alias BnApis.Accounts.Credential
  alias BnApis.Helpers.Time
  alias BnApis.Posts

  @activities_list [:last_post]
  @min_last_post_days 7

  def activities(broker_id) do
    @activities_list
    |> Enum.map(&apply(ActivityHelper, &1, [broker_id]))
  end

  def last_post(broker_id) do
    credential = broker_id |> Credential.get_credential_from_broker_id()

    if is_nil(credential) do
      %{}
    else
      last_post_days = Posts.get_last_post_days(credential)

      %{
        reason: :last_post,
        last_post: last_post_check(last_post_days),
        last_post_days: last_post_days_check(last_post_days)
      }
      |> add_common_info(credential)
    end
  end

  def add_common_info(data, credential) do
    data
    |> Map.merge(%{
      last_active_at: credential.last_active_at |> Time.naive_to_epoch(),
      last_active_at_in_days: credential.last_active_at |> Time.get_difference_in_days()
    })
  end

  def get_broker_activities(broker_id) do
    broker_id |> activities()
  end

  defp last_post_check(nil), do: true
  defp last_post_check(last_post_days), do: last_post_days > @min_last_post_days

  defp last_post_days_check(nil), do: 0
  defp last_post_days_check(last_post_days), do: last_post_days
end
