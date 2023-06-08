defmodule Mix.Tasks.CorrectExpiryTime do
  use Mix.Task
  alias BnApis.Repo
  import Ecto.Query
  alias BnApis.Posts.{RentalClientPost, RentalPropertyPost, ResaleClientPost, ResalePropertyPost}

  @shortdoc "change expiry times to end of day for all posts"
  def run(_) do
    Mix.Task.run("app.start", [])
    update_rental_client_posts()
    update_rental_property_posts()
    update_resale_client_posts()
    update_resale_property_posts()
  end

  def update_rental_client_posts do
    RentalClientPost
    |> where([rcp], not is_nil(rcp.expires_in))
    |> Repo.all()
    |> Enum.reject(&is_nil(&1.expires_in))
    |> Enum.each(fn post ->
      expires_in = post.expires_in |> get_expiry_time()

      post
      |> RentalClientPost.changeset(%{expires_in: expires_in})
      |> Repo.update()
    end)
  end

  def update_rental_property_posts do
    RentalPropertyPost
    |> where([rpp], not is_nil(rpp.expires_in))
    |> Repo.all()
    |> Enum.each(fn post ->
      expires_in = post.expires_in |> get_expiry_time()

      post
      |> RentalPropertyPost.changeset(%{expires_in: expires_in})
      |> Repo.update()
    end)
  end

  def update_resale_client_posts do
    ResaleClientPost
    |> where([rcp], not is_nil(rcp.expires_in))
    |> Repo.all()
    |> Enum.each(fn post ->
      expires_in = post.expires_in |> get_expiry_time()

      post
      |> ResaleClientPost.changeset(%{expires_in: expires_in})
      |> Repo.update()
    end)
  end

  def update_resale_property_posts do
    ResalePropertyPost
    |> where([rpp], not is_nil(rpp.expires_in))
    |> Repo.all()
    |> Enum.each(fn post ->
      expires_in = post.expires_in |> get_expiry_time()

      post
      |> ResalePropertyPost.changeset(%{expires_in: expires_in})
      |> Repo.update()
    end)
  end

  def get_expiry_time(expiry_time) do
    datetime_tuple = expiry_time |> NaiveDateTime.to_erl()
    date_tuple = datetime_tuple |> elem(0)
    end_time_tuple = {18, 29, 59}
    BnApis.Helpers.Time.erl_to_naive({date_tuple, end_time_tuple})
  end
end
