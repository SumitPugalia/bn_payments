defmodule Mix.Tasks.PostMatchTrigger do
  use Mix.Task

  alias BnApis.Repo
  import Ecto.Query

  alias BnApis.Posts.{
    RentalClientPost,
    RentalPropertyPost,
    RentalMatch,
    ResaleClientPost,
    ResalePropertyPost,
    ResaleMatch
  }

  @shortdoc "trigger matches"
  def run(_) do
    Mix.Task.run("app.start", [])
    trigger_rent_client_matches()
    trigger_rent_property_matches()
    trigger_resale_client_matches()
    trigger_resale_property_matches()
  end

  def trigger_rent_client_matches() do
    post_ids = [283, 286, 287, 290, 302, 308, 324, 334]

    post_ids
    |> Enum.map(fn post_id ->
      post = Repo.get(RentalClientPost, post_id)
      matched_property_ids = post.id |> fetch_rental_matched_property_ids()
      BnApis.ProcessPostMatchWorker.perform("rent", "client", post_id, matched_property_ids)
      # sleep for 1 min
      :timer.sleep(60000)
    end)
  end

  def trigger_rent_property_matches() do
    post_ids = [468, 476, 478, 483, 484, 491, 494, 501, 511, 527]

    post_ids
    |> Enum.map(fn post_id ->
      post = Repo.get(RentalPropertyPost, post_id)
      matched_client_ids = post.id |> fetch_rental_matched_client_ids()
      BnApis.ProcessPostMatchWorker.perform("rent", "property", post_id, matched_client_ids)
      # sleep for 1 min
      :timer.sleep(60000)
    end)
  end

  def trigger_resale_client_matches() do
    post_ids = [122, 123, 131, 140]

    post_ids
    |> Enum.map(fn post_id ->
      post = Repo.get(ResaleClientPost, post_id)
      matched_property_ids = post.id |> fetch_resale_matched_property_ids()
      BnApis.ProcessPostMatchWorker.perform("resale", "client", post_id, matched_property_ids)
      # sleep for 1 min
      :timer.sleep(60000)
    end)
  end

  def trigger_resale_property_matches() do
    post_ids = [416, 422, 427, 431, 440, 442]

    post_ids
    |> Enum.map(fn post_id ->
      post = Repo.get(ResalePropertyPost, post_id)
      matched_client_ids = post.id |> fetch_resale_matched_client_ids()
      BnApis.ProcessPostMatchWorker.perform("resale", "property", post_id, matched_client_ids)
      # sleep for 1 min
      :timer.sleep(60000)
    end)
  end

  def fetch_rental_matched_property_ids(client_post_id) do
    RentalMatch
    |> where([rm], rm.rental_client_id == ^client_post_id)
    |> select([rm], rm.rental_property_id)
    |> Repo.all()
  end

  def fetch_rental_matched_client_ids(property_post_id) do
    RentalMatch
    |> where([rm], rm.rental_property_id == ^property_post_id)
    |> select([rm], rm.rental_client_id)
    |> Repo.all()
  end

  def fetch_resale_matched_property_ids(client_post_id) do
    ResaleMatch
    |> where([rm], rm.resale_client_id == ^client_post_id)
    |> select([rm], rm.resale_property_id)
    |> Repo.all()
  end

  def fetch_resale_matched_client_ids(property_post_id) do
    ResaleMatch
    |> where([rm], rm.resale_property_id == ^property_post_id)
    |> select([rm], rm.resale_client_id)
    |> Repo.all()
  end
end
