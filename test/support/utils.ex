defmodule BnApis.Tests.Utils do
  import ExUnit.Assertions
  import Mox
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Repo
  alias BnApis.Accounts
  alias BnApis.Helpers.Token
  alias BnApis.Factory
  alias BnApis.Posts.Buckets.Buckets
  alias BnApis.Posts
  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.DeveloperCredential
  alias BnApis.Stories
  alias BnApis.Developers
  alias BnApis.Stories.AttachmentType
  alias BnApis.Stories.LegalEntity
  alias BnApis.BookingRewards
  alias BnApis.Rewards.StoryTransaction
  alias BnApis.Stories.Invoice
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Helpers.Time, as: TimeHelper
  alias BnApis.Homeloan.LoanFiles
  alias BnApis.Homeloan.Lead

  @user_map %{user_id: 1, user_type: "test"}

  def given_reward_lead(credential, status_id) do
    lead = Factory.insert(:rewards_lead, broker_id: credential.broker.id)
    status = Factory.insert(:reward_lead_status, %{status_id: status_id, rewards_lead_id: lead.id})
    BnApis.Repo.update!(RewardsLead.latest_status_changeset(lead, %{latest_status_id: status.id}))
    |> BnApis.Repo.preload([:latest_status, :story])
  end

  def create_booking_reward_lead(config) do
    expect_pdf_generated(1)
    upload_file_s3(1)

    {:ok, lead} = booking_rewards_params(config.story.id, config.legal_entity.id) |> BookingRewards.create(@user_map |> Map.put(:broker_id, config.cred.broker.id))
    {:ok, lead} = BookingRewards.upload_pdf_and_approve("123", lead.uuid, @user_map)

    BookingRewards.update_invoice_details(
      %{
        "uuid" => lead.uuid,
        "invoice_number" => "1234",
        "invoice_date" => "1234",
        "billing_company_id" => config.billing_company.id
      },
      @user_map |> Map.put(:broker_id, config.cred.broker.id)
    )
  end

  def given_story_with_balance(initial_amount) do
    cred = Factory.insert(:credential)
    story = given_story(cred)
    legal_entity = Factory.insert(:legal_entity)
    billing_company = given_billing_company(cred.broker)
    emp = Factory.insert(:employee_credential)

    {:ok, _st} = StoryTransaction.create_story_transaction!(initial_amount, emp.id, story.id, "bn.com", "bn.com", legal_entity.id, @user_map)

    %{
      story: story,
      legal_entity: legal_entity,
      billing_company: billing_company,
      cred: cred
    }
  end

  def create_brokerage_invoice(config) do
    params = %{
      "status" => "approval_pending",
      "invoice_number" => "TESTDEV1234#",
      "invoice_date" => 1_659_690_879,
      "story_id" => config.story.id,
      "legal_entity_id" => config.legal_entity.id,
      "billing_company_id" => config.billing_company.id,
      "invoice_items" => [
        %{
          "customer_name" => "test name",
          "unit_number" => "205",
          "wing_name" => "A",
          "building_name" => "Test Building",
          "agreement_value" => 10_000_000,
          "brokerage_amount" => 100_000
        }
      ]
    }

    Invoice.create_invoice(params, config.cred.broker.id, config.cred.broker_role_id, config.cred.broker.role_type_id, config.cred.organization_id, @user_map)
  end

  def create_loan_file(lead) do
    emp = Factory.insert(:employee_credential)
    {:ok, _} =
      LoanFiles.create_loan_file_from_panel(
        %{
          "lead_id" => lead.id,
          "loan_files" => [%{"branch_location" => Faker.Address.En.secondary_address(), "bank_id" => 1, "application_id" => random_mobile_number()}]
        },
        %{"profile" => %{"employee_id" => emp.id}}
      )
  end

  def create_dsa_invoice(dsa, cred, loan_disbursed) do
    # lead = Factory.insert(:dsa_lead)
    BnApis.Homeloan.Bank.update_bank(%{"id" => "1", "commission_on" => "disbursement_amount"})

   {:ok, lead} = Lead.create_lead!(
        random_mobile_number(),
        1,
        Faker.Person.En.first_name(),
        Faker.Cat.En.breed(),
        dsa.id,
        loan_disbursed,
        "1",
        TimeHelper.now_to_epoch_sec(),
        Faker.Cat.En.breed(),
        Faker.Cat.En.breed(),
        "Home Loan",
        "Ready to move",
        "Residential",
        "bn",
        "GAHLK8970P",
        nil
      )

    {:ok, [file]} = create_loan_file(lead)

    {:ok, loan} = LoanDisbursement.add_homeloan_disbursement(
      %{
        "lead_id" => lead.id,
        "disbursement_date" => TimeHelper.now_to_epoch_sec(),
        "loan_disbursed" => loan_disbursed,
        "loan_file_id" => file.id
      }
    )

    billing_company = given_billing_company(dsa)

    params = %{
      "status" => "invoice_requested",
      "invoice_number" => "invoice-number #{Time.to_iso8601(Time.utc_now())}",
      "invoice_date" => TimeHelper.now_to_epoch_sec(),
      "loan_disbursements_id" => loan.id,
      "legal_entity_id" => "bn",
      "billing_company_id" => billing_company.id
    }

    {:ok, invoice} = Invoice.create_invoice(params, dsa.id, cred.broker_role_id, cred.broker.role_type_id, cred.organization_id, @user_map)
    Invoice.get_invoice_by_uuid(invoice["uuid"])
  end

  def upload_file_s3(count \\ 1) do
    expect(S3Mock, :upload_file_s3, count, fn _, _ -> "/" end)
  end

  def expect_pdf_generated(count \\ 1) do
    expect(HtmlMock, :generate_pdf_from_html_api, count, fn _, _, _, _ -> "/" end)
  end

  def expect_s3_put_file(count \\ 1) do
    expect(S3Mock, :put_file, count, fn _, _, _, _ -> {:ok, "Success"} end)
  end

  def expect_redis(command_in, result, count \\ 1) do
    expect(RedisMock, :q, count, fn command ->
      assert command_in -- command == []
      {:ok, result}
    end)
  end

  def expect_redis_error(command_in) do
    expect(RedisMock, :q, fn command ->
      assert command_in -- command == []
      {:error, nil}
    end)
  end

  def expect_sms(phone_number, message_in, type \\ nil) do
    if type in [nil, :sms] do
      expect(SmsServiceMock, :send_sms, fn to, message, _, _, _ ->
        assert to =~ phone_number
        assert message =~ message_in
        {:ok, %{}}
      end)
    end

    if type in [nil, :otp] do
      expect(SmsOtpServiceMock, :send_otp_sms_api, fn to, _message ->
        assert to =~ phone_number
        {:ok, %{}}
      end)
    end
  end

  def mock_send_otp_redis(otp, phone_number, type \\ nil) do
    expect_redis(["otp"], otp)
    expect_redis(["HINCRBY"], 1)
    expect_redis(["otp_request_count"], 1)
    expect_sms(phone_number, otp, type)
    # expect_otp_sms(phone_number, otp)
  end

  def mock_verify_otp_sucess_redis(otp) do
    expect_redis(["otp"], otp)
    expect_redis(["HINCRBY"], 1)
    expect_redis(["DEL"], "OK")
    expect_redis([], "", 4)
  end

  def mock_signup_invite_user_redis(phone_number) do
    expect_redis(["HMGET"], [phone_number, nil])
    expect_s3_put_file()
    expect_redis(["DEL"], "")

    expect_redis(["smembers"], [])
    expect_redis([], "", 2)
    expect_redis(["hsetnx"], 1)

    expect_redis([], "", 5)
    expect_redis(["hget"], nil)
  end

  def get_broker_token() do
    expect(SlackNotificationMock, :send_slack_notification, fn text, _, _ -> Regex.match?(~r/sendbird/, text) end)
    expect(SlackNotificationMock, :send_slack_notification, fn text, _, _ -> Regex.match?(~r/sendbird/, text) end)

    {:ok, credential} =
      Accounts.create_account_info(
        %{"phone_number" => random_mobile_number(), "country_code" => "+91", "organization_name" => Faker.Company.name(), "broker_name" => ExMachina.sequence("Name-")},
        %{user_id: 1, user_type: "Employee"}
      )

    {:ok, token} = Token.initialize_broker_token(credential.uuid)
    %{token: token, broker_id: credential.broker_id, credential_id: credential.id}
  end

  def expect_http(type, inurl, status_code, response) do
    expect(HTTPMock, :request, fn ^type, url, _, _, _ ->
      assert url =~ inurl

      {:ok,
       %HTTPoison.Response{
         status_code: status_code,
         body: response,
         headers: []
       }}
    end)
  end

  def given_bucket(type, broker_id), do: given_bucket(type, broker_id, %{})

  def given_bucket(:locality_id, broker_id, attrs) do
    valid_params =
      %{
        "name" => "bucket_name",
        "filters" => %{
          "post_type" => 1,
          "configuration_type" => [1, 2],
          "location_name" => "Powai",
          "locality_id" => 1
        }
      }
      |> Map.merge(attrs)

    {:ok, bucket} = Buckets.create(valid_params, broker_id)
    bucket
  end

  def given_bucket(:google_place_id, broker_id, attrs) do
    valid_params =
      %{
        "name" => "test_bucket",
        "filters" => %{
          "post_type" => 1,
          "configuration_type" => [1, 2],
          "location_name" => "Powai",
          "google_place_id" => "ChIJndMI5-3F5zsRbRM_-mTnGtg"
        }
      }
      |> Map.merge(attrs)

    {:ok, bucket} = Buckets.create(valid_params, broker_id)
    bucket
  end

  def given_bucket(:building_ids, broker_id, attrs) do
    valid_params =
      %{
        "name" => "test_bucket",
        "filters" => %{
          "post_type" => 1,
          "configuration_type" => [1, 2],
          "location_name" => "Powai",
          "building_ids" => Map.get(attrs, "building_ids")
        }
      }
      |> Map.merge(attrs)

    {:ok, bucket} = Buckets.create(valid_params, broker_id)
    bucket
  end

  def given_posts(:rental_property, credential_id, attrs \\ %{}) do
    building = BnApis.Repo.get_by(BnApis.Buildings.Building, name: "Test Castle")

    valid_params =
      %{
        "is_bachelor_allowed" => true,
        "rent_expected" => Enum.random([10000, 20000, 15000, 25000]),
        "user_id" => credential_id,
        "building_id" => building.uuid,
        "configuration_type_id" => Enum.random([1, 2]),
        "furnishing_type_id" => 3,
        "notes" => "Quiet",
        "commit" => false,
        "assigned_user_id" => credential_id,
        "uploader_type" => "owner",
        "owner_phone" => "9582557758",
        "owner_name" => "OwnerTest"
      }
      |> Map.merge(attrs)

    {:ok, post} = Posts.create_rental_property(valid_params)
    post
  end

  def expect_token(uuid) do
    expect_redis(["user_uuid"], uuid)
    expect_redis_error(["expires_in"])
  end

  def given_broker(), do: Factory.insert(:broker)
  def given_legal_entity(), do: Factory.insert(:legal_entity)
  def given_billing_company(broker), do: Factory.insert(:billing_company, broker: broker)

  def given_story(credential) do
    story_tier = Factory.insert(:story_tier)

    Factory.insert(:story, %{is_rewards_enabled: true, operating_cities: [credential.broker.operating_city], default_story_tier_id: story_tier.id})
  end

  def random_mobile_number, do: "#{Enum.random(9_000_000_000..9_999_999_999)}"

  defp booking_rewards_params(story_id, legal_entity_id) do
    %{
      "unit_details" => %{
        "booking_date" => 1_661_428_300,
        "booking_form_number" => "24",
        "rera_number" => "rera1",
        "unit_number" => "15",
        "rera_carpet_area" => 300,
        "building_name" => "b1",
        "wing" => "A",
        "agreement_value" => 20000,
        "agreement_proof" => "purl",
        "story_id" => story_id,
        "legal_entity_id" => legal_entity_id
      },
      "booking_client" => %{
        "name" => "gagan",
        "pan_number" => "GAHLK8970P",
        "pan_card_image" => "pan",
        "permanent_address" => "ad",
        "address_proof" => "lhejbj"
      },
      "booking_payment" => %{
        "token_amount" => 100,
        "payment_mode" => "cheque",
        "payment_proof" => "url"
      },
      "status" => "pending"
    }
  end
end
