defmodule BnApis.Stories.InvoiceTest do
  use BnApis.DataCase, async: true
  import Mox

  alias BnApis.Factory
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Organizations.Broker
  alias BnApis.Repo
  alias BnApis.Stories.Invoice
  alias BnApis.Stories.Schema.Invoice, as: InvoiceSchema
  alias BnApis.Tests.Utils

  setup :verify_on_exit!

  @user_map %{user_id: 123, user_type: "test"}
  @loan_commission_percent 20

  describe "create_invoice/2" do
    test "successfully creates an invoice" do
      credential = Factory.insert(:credential)
      legal_entity = Factory.insert(:legal_entity)
      story = given_story(credential)
      billing_company = Factory.insert(:billing_company)

      params = given_invoice_params(story.id, legal_entity.id, billing_company.id)

      {:ok, invoice} = Invoice.create_invoice(params, credential.broker.id, @user_map)
      assert invoice["story_id"] == story.id
      assert invoice["legal_entity_id"] == legal_entity.id
    end
  end

  describe "update_invoice/2" do
    test "successfully update an invoice" do
      # given
      credential = Factory.insert(:credential)
      legal_entity = Factory.insert(:legal_entity)
      story = given_story(credential)
      billing_company = Factory.insert(:billing_company)

      params = given_invoice_params(story.id, legal_entity.id, billing_company.id)
      {:ok, invoice} = Invoice.create_invoice(params, credential.broker.id, @user_map)

      assert invoice["status"] == "draft"

      # when
      params =
        Map.take(params, ~w(invoice_number invoice_date legal_entity_id billing_company_id))
        |> Map.merge(%{
          "uuid" => invoice["uuid"],
          "status" => "approval_pending",
          "invoice_items" => [],
          "homeloan_lead_id" => 1
        })

      {:ok, invoice} = Invoice.update_invoice_for_broker(params, credential.broker.id, @user_map)
      # then
      assert invoice.status == "approval_pending"
      assert invoice.entity_type == :homeloan_leads
      assert invoice.entity_id == 1
    end
  end

  describe "add_tax_and_total_invoice_amount_dsa/1" do
    setup config do
      dsa = Factory.insert(:broker, %{role_type_id: 2})
      cred = Factory.insert(:credential, %{broker: dsa})
      Map.merge(config, %{dsa: %{credential: cred, broker: dsa}})
    end

    test "when hold_gst is true and is_tds_valid is false", %{dsa: %{credential: cred, broker: dsa}} do
      invoice =
        Utils.create_dsa_invoice(dsa, cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: true, is_tds_valid: false})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      refute invoice.is_tds_valid
      assert invoice.hold_gst
      assert invoice.total_invoice_amount == "19.00"
      assert invoice.tds_percentage == 0.05
    end

    test "when hold_gst is true and is_tds_valid is true", %{dsa: %{credential: cred, broker: dsa}} do
      invoice =
        Utils.create_dsa_invoice(dsa, cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: true, is_tds_valid: true})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      assert invoice.is_tds_valid
      assert invoice.hold_gst
      assert invoice.total_invoice_amount == "16.00"
      assert invoice.tds_percentage == 0.2
    end

    test "when hold_gst is false and is_tds_valid is true", %{dsa: %{credential: cred, broker: dsa}} do
      invoice =
        Utils.create_dsa_invoice(dsa, cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: false, is_tds_valid: true})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      assert invoice.is_tds_valid
      refute invoice.hold_gst
      assert invoice.total_invoice_amount == "16.00"
      assert invoice.tds_percentage == 0.2
    end

    test "when hold_gst is false and is_tds_valid is false", %{dsa: %{credential: cred, broker: dsa}} do
      invoice =
        Utils.create_dsa_invoice(dsa, cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: false, is_tds_valid: false})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      refute invoice.is_tds_valid
      refute invoice.hold_gst
      assert invoice.total_invoice_amount == "19.00"
      assert invoice.tds_percentage == 0.05
    end

    test "when broker is from maharashtra", %{dsa: %{credential: cred, broker: dsa}} do
      dsa = Repo.update!(Broker.changeset(dsa, %{operating_city: 1}))

      invoice =
        dsa
        |> Utils.create_dsa_invoice(cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: false, is_tds_valid: true})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      assert invoice.is_tds_valid
      refute invoice.hold_gst
      assert invoice.total_invoice_amount == "16.00"
      assert invoice.tds_percentage == 0.2
    end

    test "when broker is outside maharashtra", %{dsa: %{credential: cred, broker: dsa}} do
      dsa = Repo.update!(Broker.changeset(dsa, %{operating_city: 37}))

      invoice =
        dsa
        |> Utils.create_dsa_invoice(cred, 100)
        |> InvoiceSchema.changeset(%{hold_gst: false, is_tds_valid: true})
        |> Repo.update!()
        |> Invoice.add_tax_and_total_invoice_amount_dsa(@loan_commission_percent)

      assert invoice.is_tds_valid
      refute invoice.hold_gst
      assert invoice.total_invoice_amount == "16.00"
      assert invoice.tds_percentage == 0.2
    end
  end

  defp given_invoice_params(story_id, legal_entity_id, billing_company_id) do
    %{
      "status" => "draft",
      "invoice_number" => "TEST_INVOICE_1",
      "invoice_date" => 1_664_562_600,
      "story_id" => story_id,
      "legal_entity_id" => legal_entity_id,
      "billing_company_id" => billing_company_id,
      "invoice_items" => [
        %{
          "customer_name" => "test name",
          "unit_number" => "205",
          "wing_name" => "A",
          "building_name" => "Test Building",
          "agreement_value" => 300,
          "brokerage_amount" => 113,
          "brokerage_percent" => 10.111115
        }
      ]
    }
  end

  defp given_story(credential) do
    Factory.insert(:story, %{is_rewards_enabled: true, operating_cities: [credential.broker.operating_city]})
  end

  describe "valid_wallet_balance?/1" do
    test "false when booking_reward exist but balance is 10k" do
      config = given_story_with_balance(10000)
      {:ok, lead} = create_booking_reward_lead(config)
      lead = Repo.preload(lead, [:invoices])
      [booking_reward_invoice] = lead.invoices

      refute Invoice.valid_wallet_balance?(booking_reward_invoice)
    end

    test "true when booking_reward exist but balance is 20k" do
      config = given_story_with_balance(20000)
      {:ok, lead} = create_booking_reward_lead(config)
      create_brokerage_invoice(config)
      lead = Repo.preload(lead, [:invoices])
      [booking_reward_invoice] = lead.invoices

      assert Invoice.valid_wallet_balance?(booking_reward_invoice) == true
    end

    test "false when booking_reward and brokerage reward exist but balance is 15k" do
      config = given_story_with_balance(15000)
      {:ok, lead} = create_booking_reward_lead(config)
      create_brokerage_invoice(config)
      lead = Repo.preload(lead, [:invoices])
      [booking_reward_invoice | _] = lead.invoices

      refute Invoice.valid_wallet_balance?(booking_reward_invoice)
    end
  end

  defdelegate create_booking_reward_lead(config), to: Utils

  defdelegate given_story_with_balance(initial_amount), to: Utils

  defdelegate create_brokerage_invoice(config), to: Utils
end
