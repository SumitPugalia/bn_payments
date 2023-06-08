defmodule BnApis.Rewards.StoryAmountReconcileNotificationWorker do
  alias BnApis.Helpers.ApplicationHelper
  alias BnApis.Stories.Story
  alias BnApis.Helpers.SmsService
  alias BnApis.Repo
  import Ecto.Query

  def perform() do
    try do
      reward_story_ids = Repo.all(from(s in Story, where: s.is_rewards_enabled == true, select: s.id))

      reward_story_ids
      |> Enum.each(fn id ->
        story = Repo.get_by(Story, id: id) |> Repo.preload([:rewards_bn_poc])
        balances = Story.get_story_balances(story)

        if balances[:total_credits_amount] - balances[:total_debits_amount] - balances[:total_approved_amount] <
             balances[:story_tier_amount] * 25 and not is_nil(story.rewards_bn_poc) do
          bn_poc_phone_number = story.rewards_bn_poc.phone_number
          message = "Balance low for #{story.name}"
          SmsService.send_sms(bn_poc_phone_number, message, false)
        end
      end)
    rescue
      error ->
        channel = ApplicationHelper.get_slack_channel()

        ApplicationHelper.notify_on_slack(
          "Error in amount reconcile notification worker #{Exception.message(error)}",
          channel
        )
    end
  end
end
