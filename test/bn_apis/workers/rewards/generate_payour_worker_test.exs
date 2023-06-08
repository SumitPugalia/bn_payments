defmodule BnApis.Rewards.GeneratePayourWorkerTest do
  import Mox

  use BnApis.DataCase, async: true

  alias BnApis.Factory
  alias BnApis.Rewards.GeneratePayoutWorker
  alias BnApis.Accounts.Schema.GatewayToCityMapping
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Organizations.Organization

  @user_map %{user_id: 1, user_type: "1"}

  setup :verify_on_exit!

  describe "perform/2" do
    test "when doesn't have legacy razorpay details or payment_gateway details" do
      # given
      {lead, _} = given_reward_lead()
      # then
      expect_no_denarri_payout()
      expect_not_called_razorpay_payout()

      GeneratePayoutWorker.perform(lead.id)
    end

    test "when have legacy razorpay details but not payment_gateway details" do
      # given
      razorpay_fund_account_id = Ecto.UUID.generate()

      {lead, _} =
        given_reward_lead(%{
          razorpay_contact_id: Ecto.UUID.generate(),
          razorpay_fund_account_id: razorpay_fund_account_id
        })

      # then
      expect_razorpay_payout(razorpay_fund_account_id, lead.id)
      GeneratePayoutWorker.perform(lead.id)
    end

    test "when have payment_gateway details (razorpay) but not legacy details" do
      # given

      {lead, credential} = given_reward_lead()

      payment_mapping =
        given_payment_gateway_details(
          GatewayToCityMapping.razorpay(),
          credential.uuid,
          credential.broker.operating_city
        )

      # then
      expect_razorpay_payout(payment_mapping.fund_account_id, lead.id)
      GeneratePayoutWorker.perform(lead.id)
    end

    test "when have payment_gateway details (denarri) but not legacy details" do
      # given

      {lead, credential} = given_reward_lead()

      payment_mapping = given_payment_gateway_details(GatewayToCityMapping.denarri(), credential.uuid, credential.broker.operating_city)

      # then
      expect_denarri_payout(payment_mapping.contact_id, payment_mapping.fund_account_id, lead.id)
      GeneratePayoutWorker.perform(lead.id)
    end

    test "when have payment_gateway details (denarri) and legacy details also exist, new payment_gateway takes precedence" do
      # given
      razorpay_fund_account_id = Ecto.UUID.generate()

      {lead, credential} =
        given_reward_lead(%{
          razorpay_contact_id: Ecto.UUID.generate(),
          razorpay_fund_account_id: razorpay_fund_account_id
        })

      payment_mapping = given_payment_gateway_details(GatewayToCityMapping.denarri(), credential.uuid, credential.broker.operating_city)

      # then
      expect_not_called_razorpay_payout()
      expect_denarri_payout(payment_mapping.contact_id, payment_mapping.fund_account_id, lead.id)
      GeneratePayoutWorker.perform(lead.id)
    end

    test "when organization has team UPI enabled" do
      {lead, cred} = given_reward_lead(%{razorpay_contact_id: Ecto.UUID.generate(), razorpay_fund_account_id: Ecto.UUID.generate(), upi_id: "dev@bn"})

      admin_cred =
        Factory.insert(:credential, %{razorpay_contact_id: Ecto.UUID.generate(), razorpay_fund_account_id: Ecto.UUID.generate(), organization: cred.organization, upi_id: "dev2@bn"})

      {:ok, _} = Organization.toggle_team_upi(admin_cred.id, 1, @user_map, "enable")

      expect_razorpay_payout(admin_cred.razorpay_fund_account_id, lead.id)
      GeneratePayoutWorker.perform(lead.id)
      lead = BnApis.Repo.reload!(lead) |> BnApis.Repo.preload([:latest_status])

      assert lead.latest_status.status_id == 4
    end
  end

  defp given_reward_lead(credential_attrs \\ %{}) do
    credential = Factory.insert(:credential, Map.merge(%{razorpay_contact_id: nil, razorpay_fund_account_id: nil}, credential_attrs))
    lead = Factory.insert(:rewards_lead, broker_id: credential.broker.id)
    status = Factory.insert(:reward_lead_status, %{status_id: 3, rewards_lead_id: lead.id})
    BnApis.Repo.update!(RewardsLead.latest_status_changeset(lead, %{latest_status_id: status.id}))
    {lead, credential}
  end

  defp given_payment_gateway_details(name, client_uuid, city_id) do
    Factory.insert(:payout_mapping, %{name: name, client_uuid: client_uuid, city_id: city_id})
  end

  defp expect_razorpay_payout(razorpay_fund_account_id, reference_id) do
    expect(PaymentGatewayMock, :create_razorpay_payout, fn ^razorpay_fund_account_id, _, ^reference_id, "g", _ ->
      {200, get_payout_response(razorpay_fund_account_id, reference_id)}
    end)
  end

  defp expect_denarri_payout(contact_id, fund_account_id, reference_id) do
    expect(PaymentGatewayMock, :make_payment_via_denarri, fn ^contact_id, ^fund_account_id, _, ^reference_id, _ ->
      {200, get_payout_response(fund_account_id, reference_id)}
    end)
  end

  defp expect_no_denarri_payout do
    expect(PaymentGatewayMock, :make_payment_via_denarri, 0, fn _, _, _, _, _ -> :ok end)
  end

  defp expect_not_called_razorpay_payout do
    expect(PaymentGatewayMock, :create_razorpay_payout, 0, fn _, _, _, _, _ -> :ok end)
  end

  defp get_payout_response(fund_account_id, reference_id),
    do: %{
      "id" => Ecto.UUID.generate(),
      "status" => "processed",
      "amount" => "30000",
      "purpose" => "payout",
      "fund_account_id" => fund_account_id,
      "currency" => "INR",
      "mode" => "UPI",
      "reference_id" => "#{reference_id}",
      "created_at" => DateTime.to_unix(DateTime.utc_now())
    }

  defp expect_slack_notify(message),
    do: expect(SlackNotificationMock, :send_slack_notification, fn text, _, _ -> assert message == text end)
end
