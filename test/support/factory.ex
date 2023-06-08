defmodule BnApis.Factory do
  use ExMachina.Ecto, repo: BnApis.Repo

  alias BnApis.Accounts.Credential
  alias BnApis.Accounts.DeveloperPocCredential
  alias BnApis.Accounts.EmployeeCredential
  alias BnApis.Accounts.Schema.GatewayToCityMapping
  alias BnApis.Accounts.Schema.PayoutMapping
  alias BnApis.Developers.Developer
  alias BnApis.Organizations.Broker
  alias BnApis.Rewards.RewardsLead
  alias BnApis.Stories.Story
  alias BnApis.Rewards.RewardsLeadStatus
  alias BnApis.BookingRewards.Schema.BookingRewardsLead
  alias BnApis.Stories.LegalEntity
  alias BnApis.Organizations.BillingCompany
  alias BnApis.Organizations.BankAccount
  alias BnApis.Rewards.StoryTier
  alias BnApis.Organizations.Organization
  alias BnApis.Places.Polygon
  alias BnApis.Buildings.Building
  alias BnApis.Accounts.DeveloperCredential
  alias BnApis.Homeloan.Lead
  alias BnApis.Homeloan.LoanDisbursement
  alias BnApis.Helpers.Time

  def developer_credential_factory do
    %DeveloperCredential{
      name: Faker.Person.En.first_name(),
      phone_number: random_mobile_number(),
    }
  end

  def building_factory(map) do
    %Building{
      name: Faker.Pokemon.En.name(),
      polygon: build(:polygon, map),
      display_address: Faker.Address.En.secondary_address(),
      type: "residential"
    }
  end

  def polygon_factory(map) do
    %Polygon{
      name: Faker.Person.first_name(),
      rent_config_expiry: %{},
      resale_config_expiry: %{},
      rent_match_parameters: %{},
      resale_match_parameters: %{},
      city_id: map.city_id
    }
  end


  def dsa_lead_factory() do
    %Lead{name: Faker.Person.name(), country_id: 1, broker: build(:broker), external_link: Faker.Internet.url()}
  end

  def loan_disbursement_factory() do
    %LoanDisbursement{
      disbursement_date: Time.now_to_epoch_sec(),
      #  loan_disbursed: ,
      #  homeloan_lead_id: ,
      active: true
    }
  end

  def reward_lead_status_factory do
    %RewardsLeadStatus{}
  end

  def story_tier_factory do
    %StoryTier{amount: 300, name: Faker.Company.name(), employee_credential: build(:employee_credential)}
  end

  def legal_entity_factory do
    %LegalEntity{legal_entity_name: Faker.Company.name(), pan: get_pan(), gst: get_gst(), place_of_supply: "delhi"}
  end

  def bank_account_factory do
    acc_no = "#{random_int()}"

    %BankAccount{
      account_holder_name: Faker.Company.name(),
      ifsc: "UTIB0004020",
      bank_account_type: "Savings",
      account_number: acc_no,
      confirm_account_number: acc_no,
      bank_name: "SBI"
    }
  end

  def billing_company_factory do
    %BillingCompany{
      name: Faker.Company.name(),
      address: Faker.Address.street_address(),
      place_of_supply: "delhi",
      company_type: "One Person Company",
      pan: get_pan(),
      rera_id: Faker.String.base64(),
      bill_to_state: Faker.String.base64(),
      bill_to_pincode: pincode(),
      bill_to_city: "delhi",
      broker: build(:broker),
      bank_account: build(:bank_account)
    }
  end

  def broker_factory do
    %Broker{
      name: sequence("Name-"),
      operating_city: 1
    }
  end

  def rewards_lead_factory do
    %RewardsLead{
      name: sequence("Reward Name-"),
      # broker_id: broker_id,
      story: build(:story),
      developer_poc_credential: build(:developer_poc_credential),
      release_employee_payout: true
      # latest_status: build(:rewards_lead_status, %{status_id: 8})
    }
  end

  def story_factory do
    %Story{
      name: sequence("Story Name-"),
      interval: 1,
      developer: build(:developer)
    }
  end

  def developer_factory do
    %Developer{
      name: sequence("Developer Name-"),
      email: sequence(:email, &"email-#{&1}@example.com"),
      logo_url: ""
    }
  end

  def developer_poc_credential_factory do
    %DeveloperPocCredential{name: sequence("Developer POC Name-"), phone_number: random_mobile_number()}
  end

  def payout_mapping_factory(attrs) do
    %PayoutMapping{
      contact_id: Ecto.UUID.generate(),
      fund_account_id: Ecto.UUID.generate(),
      active: true,
      cilent_uuid: Map.get(attrs, :client_uuid),
      payment_gateway: build(:payment_gateway, attrs)
    }
  end

  def payment_gateway_factory(attrs) do
    %GatewayToCityMapping{
      city_ids: [Map.get(attrs, :city_id)],
      active: true,
      name: Map.get(attrs, :name)
    }
  end

  def credential_factory do
    %Credential{
      uuid: Ecto.UUID.generate(),
      phone_number: random_mobile_number(),
      profile_type_id: 1,
      razorpay_contact_id: "1",
      razorpay_fund_account_id: "1",
      active: true,
      broker: build(:broker),
      broker_role_id: 1,
      organization: build(:organization)
    }
  end

  def organization_factory do
    %Organization{
      name: Faker.Person.first_name(),
      firm_address: Faker.Address.En.secondary_address()
    }
  end

  def employee_credential_factory do
    %EmployeeCredential{
      name: sequence("Employee Name-"),
      phone_number: random_mobile_number(),
      active: true,
      employee_code: sequence("BN/"),
      email: sequence(:email, &"email-#{&1}@example.com"),
      city_id: 1,
      employee_role_id: 23,
      vertical_id: 1
    }
  end

  def rewards_lead_status_factory(attrs) do
    %RewardsLeadStatus{
      status_id: Map.get(attrs, :status_id),
      rewards_lead_id: Map.get(attrs, :rewards_lead_id)
    }
  end

  def booking_reward_lead_factory do
    %BookingRewardsLead{
      booking_date: Date.to_gregorian_days(Faker.Date.backward(1)),
      booking_form_number: Faker.String.base64(),
      rera_number: Faker.String.base64(),
      unit_number: Faker.String.base64(),
      rera_carpet_area: random_int(),
      building_name: Faker.String.base64(),
      wing: Faker.String.base64(),
      agreement_value: random_int(),
      agreement_proof: Faker.String.base64(),
      invoice_number: Faker.String.base64(),
      story: build(:story),
      broker: build(:broker),
      status_id: 1
    }
  end

  defp random_int, do: Enum.random(1..1000)
  defp random_mobile_number, do: "#{Enum.random(9_000_000_000..9_999_999_999)}"
  defp get_pan(), do: Randex.stream(~r/[A-Z]{5}[0-9]{4}[A-Z]{1}/i) |> Enum.take(1) |> hd()
  defp get_gst(), do: Randex.stream(~r"\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}") |> Enum.take(1) |> hd()
  def pincode(), do: Enum.random(100_000..999_999)
end
