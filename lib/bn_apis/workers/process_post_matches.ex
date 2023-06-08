defmodule BnApis.ProcessPostMatchWorker do
  @moduledoc """
  Worker responsible for processing matches for the posts.
  """

  alias BnApis.Repo
  alias BnApis.Posts.{RentalMatch, ResaleMatch, MatchHelper}

  def perform(_, _, _, _, _ \\ [], _ \\ false)

  def perform("rent", "client", client_post_id, exclude_user_ids, exclude_property_post_ids, is_test_post) do
    matching_results =
      client_post_id
      |> RentalMatch.rental_property_matches_query(exclude_user_ids, exclude_property_post_ids, is_test_post)
      |> Repo.all()

    matching_results
    |> Enum.map(&create_rental_struct/1)
    |> insert_all_rental()

    trigger_match_notifications("rent", "client", client_post_id, Enum.map(matching_results, & &1.rental_property_id))
  end

  def perform("rent", "property", property_post_id, exclude_user_ids, exclude_client_post_ids, is_test_post) do
    matching_results =
      property_post_id
      |> RentalMatch.rental_client_matches_query(exclude_user_ids, exclude_client_post_ids, is_test_post)
      |> Repo.all()

    matching_results
    |> Enum.map(&create_rental_struct/1)
    |> insert_all_rental()

    trigger_match_notifications("rent", "property", property_post_id, Enum.map(matching_results, & &1.rental_client_id))
  end

  @doc """
  FOR RESALE MATCHES
  """
  def perform("resale", "client", client_post_id, exclude_user_ids, exclude_property_post_ids, is_test_post) do
    matching_results =
      client_post_id
      |> ResaleMatch.resale_property_matches_query(exclude_user_ids, exclude_property_post_ids, is_test_post)
      |> Repo.all()

    matching_results
    |> Enum.map(&create_resale_struct/1)
    |> insert_all_resale()

    trigger_match_notifications("resale", "client", client_post_id, Enum.map(matching_results, & &1.resale_property_id))
  end

  def perform("resale", "property", property_post_id, exclude_user_ids, exclude_client_post_ids, is_test_post) do
    matching_results =
      property_post_id
      |> ResaleMatch.resale_client_matches_query(exclude_user_ids, exclude_client_post_ids, is_test_post)
      |> Repo.all()

    matching_results
    |> Enum.map(&create_resale_struct/1)
    |> insert_all_resale()

    trigger_match_notifications(
      "resale",
      "property",
      property_post_id,
      Enum.map(matching_results, & &1.resale_client_id)
    )
  end

  # defp filter_resale_results(%{
  #   resale_client_id: resale_client_id,
  #   resale_property_id: resale_property_id
  # }) do
  #   not (is_nil(resale_client_id) or is_nil(resale_property_id))
  # end

  # defp filter_rental_results(%{
  #   rental_client_id: rental_client_id,
  #   rental_property_id: rental_property_id
  # }) do
  #   not (is_nil(rental_client_id) or is_nil(rental_property_id))
  # end

  defp create_rental_struct(result) do
    %{
      rental_client_id: result.rental_client_id,
      rental_property_id: result.rental_property_id,
      is_unlocked: result.is_unlocked,
      bachelor_ed: result.bachelor_ed,
      furnishing_ed: result.furnishing_ed,
      rent_ed: result.rent_ed,
      edit_distance: MatchHelper.dotproduct(MatchHelper.rental_edit_distance_vector(result), MatchHelper.rental_weight_vector()),
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  defp create_resale_struct(result) do
    %{
      resale_client_id: result.resale_client_id,
      resale_property_id: result.resale_property_id,
      is_unlocked: result.is_unlocked,
      price_ed: result.price_ed,
      area_ed: result.area_ed,
      parking_ed: result.parking_ed,
      floor_ed: result.floor_ed,
      edit_distance: MatchHelper.dotproduct(MatchHelper.resale_edit_distance_vector(result), MatchHelper.resale_weight_vector()),
      inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    }
  end

  # @doc """
  # Inserts matches that doesn't exist.
  # """
  defp insert_all_rental([]) do
    []
  end

  defp insert_all_rental(matches) do
    RentalMatch |> Repo.insert_all(matches, on_conflict: :nothing)
  end

  defp insert_all_resale([]) do
    []
  end

  defp insert_all_resale(matches) do
    ResaleMatch |> Repo.insert_all(matches, on_conflict: :nothing)
  end

  # @doc """
  #   1. post_id can be of client post or resale post
  #   2. matching_result_ids will be id of matching property post or client post
  # """
  defp trigger_match_notifications(post_type, post_sub_type, post_id, matching_result_ids) do
    Exq.enqueue(
      Exq,
      "matches_notification",
      BnApis.MatchesNotificationWorker,
      [post_type, post_sub_type, post_id, matching_result_ids],
      max_retries: 0
    )
  end
end
