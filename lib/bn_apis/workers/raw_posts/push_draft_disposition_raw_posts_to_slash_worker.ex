defmodule BnApis.RawPosts.PushDraftDispositionRawPostsToSlashWorker do
  alias BnApis.Repo
  import Ecto.Query

  alias BnApis.Posts.RawRentalPropertyPost
  alias BnApis.Posts.RawResalePropertyPost
  alias BnApis.WorkerHelper
  alias BnApis.Helpers.Utils

  def perform() do
    emp = WorkerHelper.get_bot_employee_credential()
    user_map = Utils.get_user_map_with_employee_cred(emp.id)
    push_draft_raw_posts_to_slash(user_map)
  end

  defp push_draft_raw_posts_to_slash(user_map) do
    end_time_unix = Timex.shift(Timex.now(), hours: -1) |> DateTime.to_unix()

    RawRentalPropertyPost
    |> where([r], r.disposition == "Draft")
    |> where(
      [rrp],
      ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at)
    )
    |> Repo.all()
    |> Enum.each(fn raw_rental_property_post ->
      RawRentalPropertyPost.push_to_slash(raw_rental_property_post, user_map)
      RawRentalPropertyPost.update_post(user_map, %{"uuid" => raw_rental_property_post.uuid, "disposition" => "Fresh"})
    end)

    RawResalePropertyPost
    |> where([r], r.disposition == "Draft")
    |> where(
      [rrp],
      ^end_time_unix >= fragment("ROUND(extract(epoch from ?))", rrp.inserted_at)
    )
    |> Repo.all()
    |> Enum.each(fn raw_resale_property_post ->
      RawResalePropertyPost.push_to_slash(raw_resale_property_post, user_map)
      RawResalePropertyPost.update_post(user_map, %{"uuid" => raw_resale_property_post.uuid, "disposition" => "Fresh"})
    end)
  end
end
