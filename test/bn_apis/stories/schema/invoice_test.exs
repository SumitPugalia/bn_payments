defmodule BnApis.Stories.Schema.InvoiceTest do
  use BnApis.DataCase
  alias BnApis.Stories.Schema.Invoice
  alias BnApis.Factory

  describe "changeset/2" do
    test "success when status is changes_requested; invoice not generated via booking rewards lead" do
      broker = given_broker()
      company = given_billing_company(broker)
      entity = given_legal_entity()

      params = %{
        status: "changes_requested",
        invoice_number: "123",
        invoice_date: "123",
        broker_id: broker.id,
        legal_entity_id: entity.id,
        billing_company_id: company.id,
        type: "brokerage"
      }

      changeset = Invoice.changeset(%Invoice{}, params)
      assert changeset.valid?
    end

    test "error when status is changes_requested; invoice is generated via booking rewards lead" do
      broker = given_broker()
      company = given_billing_company(broker)
      entity = given_legal_entity()

      params = %{
        status: "changes_requested",
        invoice_number: "123",
        invoice_date: "123",
        broker_id: broker.id,
        legal_entity_id: entity.id,
        billing_company_id: company.id,
        booking_rewards_lead_id: 123,
        type: "brokerage"
      }

      changeset = Invoice.changeset(%Invoice{}, params)
      refute changeset.valid?
      assert changeset.errors == [status: {"status not allowed", []}]
    end
  end

  defp given_broker(), do: Factory.insert(:broker)
  defp given_legal_entity(), do: Factory.insert(:legal_entity)
  defp given_billing_company(broker), do: Factory.insert(:billing_company, broker: broker)
end
