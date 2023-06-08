defmodule Mix.Tasks.MarkAlreadyExpiredAsRead do
  use Mix.Task
  import Ecto.Query

  alias BnApis.Posts.{RentalPropertyPost, RentalClientPost, ResalePropertyPost, ResaleClientPost}
  alias BnApis.Repo

  @shortdoc "mark already expired posts as read"
  def run(_) do
    Mix.Task.run("app.start", [])

    update_expired_read(RentalClientPost)
    update_expired_read(RentalPropertyPost)
    update_expired_read(ResaleClientPost)
    update_expired_read(ResalePropertyPost)
  end

  def update_expired_read(post_class) do
    post_class
    |> where(
      [rp],
      rp.archived == false and
        fragment("? <= timezone('utc', NOW())", rp.expires_in)
    )
    |> Ecto.Query.update(set: [auto_expired_read: true])
    |> Repo.update_all([])
  end
end
