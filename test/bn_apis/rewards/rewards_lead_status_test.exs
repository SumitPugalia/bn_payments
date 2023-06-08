defmodule BnApis.Rewards.RewardsLeadStatusTest do
  use BnApis.DataCase
  alias BnApis.Factory
  alias BnApis.Rewards
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Rewards.RewardsLeadStatus

  describe "create_rewards_lead_status_by_backend!/2" do
    for {final_status, final_status_integer} <- [{"approved", 3}, {"rejected", 2}] do
      @final_status final_status
      @final_status_integer final_status_integer
      test "error when changing state from in_review to #{@final_status}" do
        # given
        reward_lead = given_reward_lead()
        # when
        # then
        assert_raise Ecto.InvalidChangesetError, ~r/Cannot change status from in_review to #{@final_status}/, fn ->
          RewardsLeadStatus.create_rewards_lead_status_by_backend!(reward_lead, @final_status_integer)
        end
      end
    end

    test "error when already approved" do
      # given
      reward_lead = given_reward_lead()
      # when

      reward_lead =
        Enum.reduce([1, 3, 4], reward_lead, fn id, acc ->
          RewardsLeadStatus.create_rewards_lead_status_by_backend!(acc, id)
          Repo.get_by(RewardsLead, id: acc.id) |> Repo.preload([:latest_status])
        end)

      # then
      assert_raise Ecto.InvalidChangesetError, ~r/Cannot change status from reward_received to reward_received/, fn ->
        RewardsLeadStatus.create_rewards_lead_status_by_backend!(reward_lead, 4)
      end
    end

    for {final_status, final_status_integer} <- [{"pending", 1}, {"rejected_by_manager", 9}] do
      @final_status final_status
      @final_status_integer final_status_integer
      test "success when changing state from in_review to #{@final_status}" do
        # given
        reward_lead = given_reward_lead()
        # when
        # then

        assert RewardsLeadStatus.create_rewards_lead_status_by_backend!(reward_lead, @final_status_integer)
      end
    end

    test "cannot chage state from rejected_by_manager to any other state" do
      # given
      reward_lead = given_reward_lead()
      # when
      RewardsLeadStatus.create_rewards_lead_status_by_backend!(reward_lead, 9)
      reward_lead = BnApis.Repo.get_by(RewardsLead, id: reward_lead.id)
      # then

      assert_raise Ecto.InvalidChangesetError, ~r/Cannot change status from rejected_by_manager to pending/, fn ->
        RewardsLeadStatus.create_rewards_lead_status_by_backend!(reward_lead, 1)
      end
    end
  end

  def given_reward_lead do
    credential = Factory.insert(:credential)
    developer_poc_credential = Factory.insert(:developer_poc_credential)
    story = given_story(credential)
    session_data = session(credential.broker.id, credential.broker.operating_city)

    # when
    params = %{
      "name" => Faker.Person.En.first_name(),
      "story_uuid" => story.uuid,
      "developer_poc" => developer_poc_credential
    }

    {:ok, %{"lead_id" => lead_id}} = Rewards.create_lead(params, session_data)
    BnApis.Repo.get_by(RewardsLead, id: lead_id) |> Repo.preload([:latest_status])
  end

  defp given_story(credential) do
    story_tier = Factory.insert(:story_tier)

    Factory.insert(:story, %{is_rewards_enabled: true, operating_cities: [credential.broker.operating_city], default_story_tier_id: story_tier.id})
  end

  def session(broker_id, operating_city), do: %{"profile" => %{"broker_id" => broker_id, "operating_city" => operating_city}}
end
