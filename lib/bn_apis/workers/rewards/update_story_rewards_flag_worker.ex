defmodule BnApis.Rewards.UpdateStoryRewardsFlagWorker do
  use Ecto.Schema
  import Ecto.Changeset

  alias BnApis.Repo
  alias BnApis.Stories.Story
  alias BnApis.Helpers.{AuditedRepo, Utils}

  def perform(story_id) do
    story = Repo.get(Story, story_id)
    balances = Story.get_story_balances(story)
    user_map = Utils.get_employee_user_map(%{"phone_number" => "cron", "country_code" => "+91"})

    if balances[:total_credits_amount] - balances[:total_debits_amount] - balances[:total_pending_amount] -
         balances[:total_approved_amount] < balances[:story_tier_amount] do
      story |> cast(%{"is_rewards_enabled" => false}, [:is_rewards_enabled]) |> AuditedRepo.update(user_map)
      story |> cast(%{"is_cab_booking_enabled" => false}, [:is_cab_booking_enabled]) |> AuditedRepo.update(user_map)
    else
      if not story.is_manually_deacticated_for_rewards do
        story |> cast(%{"is_rewards_enabled" => true}, [:is_rewards_enabled]) |> AuditedRepo.update(user_map)
        story |> cast(%{"is_cab_booking_enabled" => true}, [:is_cab_booking_enabled]) |> AuditedRepo.update(user_map)
      end
    end
  end
end
