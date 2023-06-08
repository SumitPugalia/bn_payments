defmodule BnApis.AutomatedProcessPostMatchesWorker do
  @moduledoc """
  Worker responsible for processing matches for the posts which have not received any matches yet.
  """
  # seconds
  @delay 30

  alias BnApis.Posts.{RentalPropertyPost, ResalePropertyPost, RentalClientPost, ResaleClientPost}
  alias BnApis.ProcessPostMatchWorker

  def perform("rent", "client") do
    RentalClientPost.fetch_unmatched_posts()
    |> Enum.map(
      &Exq.enqueue_in(Exq, "process_post_matches", @delay + add_random_seconds(), ProcessPostMatchWorker, [
        "rent",
        "client",
        &1.id,
        &1.organization_id,
        []
      ])
    )
  end

  def perform("rent", "property") do
    RentalPropertyPost.fetch_unmatched_posts()
    |> Enum.map(
      &Exq.enqueue_in(Exq, "process_post_matches", @delay + add_random_seconds(), ProcessPostMatchWorker, [
        "rent",
        "property",
        &1.id,
        &1.organization_id,
        []
      ])
    )
  end

  def perform("resale", "client") do
    ResaleClientPost.fetch_unmatched_posts()
    |> Enum.map(
      &Exq.enqueue_in(Exq, "process_post_matches", @delay + add_random_seconds(), ProcessPostMatchWorker, [
        "resale",
        "client",
        &1.id,
        &1.organization_id,
        []
      ])
    )
  end

  def perform("resale", "property") do
    ResalePropertyPost.fetch_unmatched_posts()
    |> Enum.map(
      &Exq.enqueue_in(Exq, "process_post_matches", @delay + add_random_seconds(), ProcessPostMatchWorker, [
        "resale",
        "property",
        &1.id,
        &1.organization_id,
        []
      ])
    )
  end

  def add_random_seconds do
    Enum.random(0..100)
  end
end
