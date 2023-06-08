defmodule BnApisWeb.DashboardView do
  use BnApisWeb, :view

  alias BnApisWeb.Helpers.StoryHelper

  @no_new_matches_card [
    %{
      type: "NO_NEW_MATCHES",
      data: %{}
    }
  ]

  @static_cards []

  @doc """
  {
    story_card: {
     has_more_stories: <bool>, #indicates more stories are available, pagination of 10
     stories: [story_json, ...]
    },
    calendar_card: {},
  }
  """
  def render("dashboard.json", %{
        posts_with_matches: posts_with_matches,
        expiring_posts: expiring_posts,
        user_data: _user_data,
        page: page,
        has_more: has_more,
        auto_expired_unread_posts_count: auto_expired_unread_posts_count
      }) do
    expiring_posts_count = expiring_posts |> length()
    matches_cards_data_count = posts_with_matches |> length()

    # Outstanding Matches Bucketing based on broker
    posts_with_matches = posts_with_matches |> StoryHelper.create_posts_with_matches()

    # Expiring Posts
    expiring_posts = expiring_posts |> StoryHelper.create_expiring_posts()

    count_card =
      if auto_expired_unread_posts_count != 0 do
        [
          %{
            type: "AUTO_EXPIRED_UNREAD_POSTS_COUNT",
            data: %{count: auto_expired_unread_posts_count}
          }
        ]
      else
        []
      end

    matches_cards =
      cond do
        page == 1 && matches_cards_data_count == 0 ->
          expiring_posts ++ @no_new_matches_card ++ posts_with_matches ++ count_card

        page == 1 ->
          expiring_posts ++ posts_with_matches ++ count_card

        true ->
          posts_with_matches
      end

    response = %{
      has_more: has_more,
      cards: matches_cards
    }

    # add static cards only after all matches cards
    response =
      if expiring_posts_count + matches_cards_data_count == 0 do
        put_in(response, [:cards], response[:cards] ++ @static_cards)
      else
        response
      end

    has_more = expiring_posts_count + matches_cards_data_count > 0

    cond do
      page == 1 ->
        # update card only on first page and on top
        # response |> put_in([:cards], @transaction_data_card ++ response[:cards])
        response |> put_in([:cards], response[:cards])

      true ->
        response |> Map.merge(%{has_more: has_more})
    end
  end
end
