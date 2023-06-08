defmodule BnApis.MatchesNotificationWorker do
  @moduledoc """
    Worker responsible for sending notification matches for the posts.
  """

  alias BnApis.Posts
  alias BnApis.Posts.{RentalMatch, ResaleMatch, MatchHelper}
  alias BnApis.Posts.{RentalClientPost, RentalPropertyPost, ResaleClientPost, ResalePropertyPost}
  alias BnApisWeb.Helpers.NotificationHelper

  def perform("rent", "client", client_post_id, matching_property_ids) do
    post_data = BnApisWeb.PostView.render("generic_post.json", %{post: apply(Posts, :get_rent_client_post_data, [client_post_id])})

    matches_data = RentalMatch.get_matches_data([client_post_id], matching_property_ids)

    Enum.each(matches_data, fn match_data ->
      matching_property_post = RentalPropertyPost.get_post(match_data.rental_property_id)
      assigned_user_id = matching_property_post["assigned_user_id"]
      perfect_match = match_data |> is_perfect_match("rent")
      modified_post_data = put_in(post_data, ["perfect_match"], perfect_match)

      modified_post_data =
        put_in(
          modified_post_data,
          ["info"],
          MatchHelper.client_info(
            [matching_property_post["building_name"]],
            MatchHelper.handle_matching_configs(post_data["configuration_type_ids"], [
              matching_property_post["configuration_type_id"]
            ]),
            "Rent"
          )
        )

      NotificationHelper.send_match_notification(assigned_user_id, modified_post_data, perfect_match)
    end)
  end

  def perform("rent", "property", property_post_id, matching_client_ids) do
    post_data =
      BnApisWeb.PostView.render("generic_post.json", %{
        post: apply(Posts, :get_rent_property_post_data, [property_post_id])
      })

    matches_data = RentalMatch.get_matches_data(matching_client_ids, [property_post_id])

    Enum.each(matches_data, fn match_data ->
      assigned_user_id = RentalClientPost.get_post(match_data.rental_client_id)["assigned_user_id"]
      perfect_match = match_data |> is_perfect_match("rent")
      modified_post_data = put_in(post_data, ["perfect_match"], perfect_match)
      NotificationHelper.send_match_notification(assigned_user_id, modified_post_data, perfect_match)
    end)
  end

  def perform("resale", "client", client_post_id, matching_property_ids) do
    post_data =
      BnApisWeb.PostView.render("generic_post.json", %{
        post: apply(Posts, :get_resale_client_post_data, [client_post_id])
      })

    matches_data = ResaleMatch.get_matches_data([client_post_id], matching_property_ids)

    Enum.each(matches_data, fn match_data ->
      matching_property_post = ResalePropertyPost.get_post(match_data.resale_property_id)
      assigned_user_id = matching_property_post["assigned_user_id"]
      perfect_match = match_data |> is_perfect_match("resale")
      modified_post_data = put_in(post_data, ["perfect_match"], perfect_match)

      modified_post_data =
        put_in(
          modified_post_data,
          ["info"],
          MatchHelper.client_info(
            [matching_property_post["building_name"]],
            MatchHelper.handle_matching_configs(post_data["configuration_type_ids"], [
              matching_property_post["configuration_type_id"]
            ]),
            "Resale"
          )
        )

      NotificationHelper.send_match_notification(assigned_user_id, modified_post_data, perfect_match)
    end)
  end

  def perform("resale", "property", property_post_id, matching_client_ids) do
    post_data =
      BnApisWeb.PostView.render("generic_post.json", %{
        post: apply(Posts, :get_resale_property_post_data, [property_post_id])
      })

    matches_data = ResaleMatch.get_matches_data(matching_client_ids, [property_post_id])

    Enum.each(matches_data, fn match_data ->
      assigned_user_id = ResaleClientPost.get_post(match_data.resale_client_id)["assigned_user_id"]
      perfect_match = match_data |> is_perfect_match("resale")
      modified_post_data = put_in(post_data, ["perfect_match"], perfect_match)
      NotificationHelper.send_match_notification(assigned_user_id, modified_post_data, perfect_match)
    end)
  end

  def is_perfect_match(match_data, "rent") do
    %{edit_distance: edit_distance, rent_ed: rent_ed} = match_data
    edit_distance |> Decimal.to_float() == 0 or rent_ed |> Decimal.to_float() < 0.25
  end

  def is_perfect_match(match_data, "resale") do
    %{edit_distance: edit_distance, price_ed: price_ed} = match_data
    edit_distance |> Decimal.to_float() == 0 or price_ed |> Decimal.to_float() < 0.25
  end
end
