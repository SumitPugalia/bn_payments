defmodule BnApis.RawPosts.SendPendingRawPostsToSlashWorker do
  alias BnApis.Repo
  import Ecto.Query

  alias BnApis.Posts.RawRentalPropertyPost
  alias BnApis.Posts.RawResalePropertyPost
  alias BnApis.Posts.Schema.PostLead
  alias BnApis.Posts.PostLeads
  alias BnApis.WorkerHelper
  alias BnApis.Helpers.Utils

  def perform() do
    emp = WorkerHelper.get_bot_employee_credential()
    user_map = Utils.get_user_map_with_employee_cred(emp.id)
    retry_pending_raw_rental_posts(user_map)
    retry_pending_raw_resale_posts(user_map)
    retry_pending_post_leads()
  end

  defp retry_pending_raw_rental_posts(user_map) do
    RawRentalPropertyPost
    |> where([r], r.pushed_to_slash == false)
    |> where([r], r.disposition == "Fresh")
    |> Repo.all()
    |> Enum.each(fn raw_rental_property_post ->
      RawRentalPropertyPost.push_to_slash(raw_rental_property_post, user_map)
    end)
  end

  defp retry_pending_raw_resale_posts(user_map) do
    RawResalePropertyPost
    |> where([r], r.pushed_to_slash == false)
    |> where([r], r.disposition == "Fresh")
    |> Repo.all()
    |> Enum.each(fn raw_resale_property_post ->
      RawResalePropertyPost.push_to_slash(raw_resale_property_post, user_map)
    end)
  end

  defp retry_pending_post_leads() do
    PostLead
    |> where([r], r.pushed_to_slash == false)
    |> Repo.all()
    |> Enum.each(fn lead ->
      PostLeads.push_to_slash(lead)
    end)
  end
end
