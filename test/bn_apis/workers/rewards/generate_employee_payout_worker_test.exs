defmodule BnApis.Workers.Rewards.GenerateEmployeePayoutWorkerTest do
  import Mox

  use BnApis.DataCase, async: true

  alias BnApis.Factory
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.Accounts.Schema.GatewayToCityMapping

  setup :verify_on_exit!

  describe "perform/2" do
    test "when have legacy razorpay details but not payment_gateway details" do
      razorpay_fund_account_id = Ecto.UUID.generate()

      lead =
        given_reward_lead(%{
          razorpay_contact_id: Ecto.UUID.generate(),
          razorpay_fund_account_id: razorpay_fund_account_id
        })

      expect_razorpay_payout(razorpay_fund_account_id, lead.id)
    end

    test "when have payment_gateway details (denarri) but not legacy details" do
      lead = given_reward_lead()

      payment_mapping =
        given_payment_gateway_details(
          GatewayToCityMapping.denarri(),
          lead.employee_credential.uuid,
          lead.broker.operating_city
        )

      expect_denarri_payout(payment_mapping.contact_id, payment_mapping.fund_account_id, lead.id)
    end

    test "when have payment_gateway details (razorpay) but not legacy details" do
      lead = given_reward_lead()

      payment_mapping =
        given_payment_gateway_details(
          GatewayToCityMapping.razorpay(),
          lead.employee_credential.uuid,
          lead.broker.operating_city
        )

      expect_razorpay_payout(payment_mapping.fund_account_id, lead.id)
    end

    test "when have payment_gateway details (denarri) and legacy details also exist, new payment_gateway takes precedence" do
      razorpay_fund_account_id = Ecto.UUID.generate()

      lead =
        given_reward_lead(%{
          razorpay_contact_id: Ecto.UUID.generate(),
          razorpay_fund_account_id: razorpay_fund_account_id
        })

      payment_mapping =
        given_payment_gateway_details(
          GatewayToCityMapping.razorpay(),
          lead.employee_credential.uuid,
          lead.broker.operating_city
        )

      expect_razorpay_payout(payment_mapping.fund_account_id, lead.id)
    end
  end

  defp given_reward_lead(employee_credential_attrs \\ %{}) do
    credential = Factory.insert(:credential)
    employee_credential = Factory.insert(:employee_credential, employee_credential_attrs)

    lead =
      Factory.insert(
        :rewards_lead,
        %{
          broker_id: credential.broker.id,
          visit_date: NaiveDateTime.utc_now(),
          story: Factory.build(:story, %{operating_cities: [credential.broker.operating_city]}),
          employee_credential: employee_credential,
          broker: credential.broker
        }
      )

    RewardsLeadStatus.create_rewards_lead_status_by_backend!(lead, 5)
    lead
  end

  defp given_payment_gateway_details(name, client_uuid, city_id) do
    Factory.insert(:payout_mapping, %{name: name, client_uuid: client_uuid, city_id: city_id})
  end

  defp expect_razorpay_payout(razorpay_fund_account_id, reference_id) do
    expect(PaymentGatewayMock, :create_razorpay_payout, fn ^razorpay_fund_account_id, _, ^reference_id, "e", _ ->
      {200, get_payout_response(razorpay_fund_account_id, reference_id)}
    end)
  end

  defp expect_denarri_payout(contact_id, fund_account_id, reference_id) do
    expect(PaymentGatewayMock, :make_payment_via_denarri, fn ^contact_id, ^fund_account_id, _, ^reference_id, _ ->
      {200, get_payout_response(fund_account_id, reference_id)}
    end)
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
end
