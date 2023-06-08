# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     BnApis.Repo.insert!(%BnApis.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias BnApis.Repo
alias BnApis.Seeder
import Ecto.Query
alias BnApis.Accounts.DeveloperPocCredential
Code.require_file("seeds/building_seeds.exs", __DIR__)
Code.require_file("seeds/project_connect_seeds.exs", __DIR__)
Code.require_file("seeds/pune_brokers_seeds.exs", __DIR__)
Code.require_file("seeds/transactions_districts_seeds.exs", __DIR__)

# ===================================

BnApis.Accounts.Status.seed_data()
|> Enum.each(fn status ->
  if BnApis.Accounts.Status |> where(name: ^status.name) |> where(id: ^status.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Accounts.Status.changeset(status) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Accounts.ProfileType.seed_data()
|> Enum.each(fn profile_type ->
  if BnApis.Accounts.ProfileType
     |> where(name: ^profile_type.name)
     |> where(id: ^profile_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Accounts.ProfileType.changeset(profile_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Organizations.BrokerRole.seed_data()
|> Enum.each(fn broker_role ->
  if BnApis.Organizations.BrokerRole
     |> where(name: ^broker_role.name)
     |> where(id: ^broker_role.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Organizations.BrokerRole.changeset(broker_role) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Organizations.BrokerType.seed_data()
|> Enum.each(fn broker_type ->
  if BnApis.Organizations.BrokerType
     |> where(name: ^broker_type.name)
     |> where(id: ^broker_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Organizations.BrokerType.changeset(broker_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Stories.SectionResourceType.seed_data()
|> Enum.each(fn resource_type ->
  if BnApis.Stories.SectionResourceType
     |> where(name: ^resource_type.name)
     |> where(id: ^resource_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Stories.SectionResourceType.changeset(resource_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Stories.AttachmentType.seed_data()
|> Enum.each(fn attachment_type ->
  if BnApis.Stories.AttachmentType
     |> where(name: ^attachment_type.name)
     |> where(id: ^attachment_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Stories.AttachmentType.changeset(attachment_type) |> Repo.insert!()
  end
end)

# ===================================

micro_markets_seed_data = [
  %{id: 1, name: "South Bombay"},
  %{id: 2, name: "Western Suburbs"},
  %{id: 3, name: "Central Suburbs"},
  %{id: 4, name: "Eastern Suburbs"},
  %{id: 5, name: "Mumbai Harbour"}
]

micro_markets_seed_data
|> Enum.each(fn micro_market ->
  if BnApis.Developers.MicroMarket
     |> where(name: ^micro_market.name)
     |> where(id: ^micro_market.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Developers.MicroMarket.changeset(micro_market) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Posts.ConfigurationType.seed_data()
|> Enum.each(fn config_type ->
  if BnApis.Posts.ConfigurationType
     |> where(name: ^config_type.name)
     |> where(id: ^config_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Posts.ConfigurationType.changeset(config_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Posts.FurnishingType.seed_data()
|> Enum.each(fn furnish_type ->
  if BnApis.Posts.FurnishingType
     |> where(name: ^furnish_type.name)
     |> where(id: ^furnish_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Posts.FurnishingType.changeset(furnish_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Posts.FloorType.seed_data()
|> Enum.each(fn floor_type ->
  if BnApis.Posts.FloorType |> where(name: ^floor_type.name) |> where(id: ^floor_type.id) |> Repo.aggregate(:count, :id) !=
       1 do
    BnApis.Posts.FloorType.changeset(floor_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Posts.ProjectType.seed_data()
|> Enum.each(fn project_type ->
  if BnApis.Posts.ProjectType
     |> where(name: ^project_type.name)
     |> where(id: ^project_type.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Posts.ProjectType.changeset(project_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.CallLogs.CallLogCallStatus.seed_data()
|> Enum.each(fn call_status ->
  if BnApis.CallLogs.CallLogCallStatus
     |> where(name: ^call_status.name)
     |> where(id: ^call_status.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.CallLogs.CallLogCallStatus.changeset(call_status) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Feedbacks.FeedbackRating.seed_data()
|> Enum.each(fn feedback_rating ->
  if BnApis.Feedbacks.FeedbackRating
     |> where(name: ^feedback_rating.name)
     |> where(id: ^feedback_rating.id)
     |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Feedbacks.FeedbackRating.changeset(feedback_rating) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Feedbacks.FeedbackRatingReason.seed_data()
|> Enum.each(fn feedback_rating_reason ->
  if BnApis.Feedbacks.FeedbackRatingReason |> where(id: ^feedback_rating_reason.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Feedbacks.FeedbackRatingReason.changeset(feedback_rating_reason) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Accounts.InviteStatus.seed_data()
|> Enum.each(fn invite_status ->
  if BnApis.Accounts.InviteStatus |> where(id: ^invite_status.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Accounts.InviteStatus.changeset(invite_status) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Accounts.EmployeeVertical.seed_data()
|> Enum.each(fn vertical ->
  if BnApis.Accounts.EmployeeVertical |> where(id: ^vertical["id"]) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Accounts.EmployeeVertical.changeset(vertical) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Accounts.EmployeeRole.seed_data()
|> Enum.each(fn employee_role ->
  if BnApis.Accounts.EmployeeRole |> where(id: ^employee_role.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Accounts.EmployeeRole.changeset(employee_role) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Transactions.DocType.seed_data()
|> Enum.each(fn doctype ->
  if BnApis.Transactions.DocType |> where(id: ^doctype.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Transactions.DocType.changeset(doctype) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Reasons.ReasonType.seed_data()
|> Enum.each(fn reason_type ->
  if BnApis.Reasons.ReasonType |> where(id: ^reason_type.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Reasons.ReasonType.changeset(reason_type) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Reasons.Reason.seed_data()
|> Enum.each(fn reason ->
  if BnApis.Reasons.Reason |> where(id: ^reason.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Reasons.Reason.changeset(reason) |> Repo.insert!()
  end
end)

# ===================================

BnApis.Transactions.Status.seed_data()
|> Enum.each(fn status ->
  if BnApis.Transactions.Status |> where(id: ^status.id) |> Repo.aggregate(:count, :id) != 1 do
    BnApis.Transactions.Status.changeset(status) |> Repo.insert!()
  end
end)

# Seeder.Buildings.seed_data()
# Seeder.Projects.seed_data()
# Seeder.BrokerUniverse.seed_data()

Seeder.TransactionDistrictSeed.seed_data()

# =========== HomeLoan =============
BnApis.Homeloan.Country.seed_data()
|> Enum.each(fn data ->
  case Repo.get_by(BnApis.Homeloan.Country, url_name: data.url_name) do
    nil ->
      BnApis.Homeloan.Country.changeset(%BnApis.Homeloan.Country{}, data) |> Repo.insert!()

    country ->
      BnApis.Homeloan.Country.changeset(country, data) |> Repo.update!()
  end
end)

BnApis.Homeloan.Bank.seed_data()
|> Enum.each(fn {_id, data} ->
  case Repo.get_by(BnApis.Homeloan.Bank, name: data["name"]) do
    nil ->
      BnApis.Homeloan.Bank.changeset(%BnApis.Homeloan.Bank{}, data) |> Repo.insert!()

    bank ->
      BnApis.Homeloan.Bank.changeset(bank, data) |> Repo.update!()
  end
end)

# =============== City ============
BnApis.Places.City.seed_data()
|> Enum.each(fn data ->
  city = Repo.get_by(BnApis.Places.City, id: data.id)

  if is_nil(city) do
    BnApis.Places.City.changeset(%BnApis.Places.City{}, data) |> Repo.insert!()
  end
end)

# =============== gateway_to_city_mapping ============
BnApis.Accounts.Schema.GatewayToCityMapping.seed_data()
|> Enum.each(fn data ->
  loc = Repo.get_by(BnApis.Accounts.Schema.GatewayToCityMapping, name: data.name)

  if is_nil(loc) do
    BnApis.Accounts.Schema.GatewayToCityMapping.changeset(%BnApis.Accounts.Schema.GatewayToCityMapping{}, data)
    |> Repo.insert!()
  end
end)

# ================ Add whatsapp user ================
manager =
  if Mix.env() == :test do
    case Repo.get_by(BnApis.Accounts.EmployeeCredential, phone_number: "test") do
      nil -> BnApis.Factory.insert(:employee_credential, %{phone_number: "test"})
      result -> result
    end
  else
    Repo.get_by(BnApis.Accounts.EmployeeCredential, phone_number: "9819619866")
  end

manager_id = manager.id
city_ids = BnApis.Places.City |> select([c], c.id) |> distinct(true) |> Repo.all()

bot_users_seed_data = [
  %{
    name: "Whatsapp Bot",
    phone_number: "whatsapp",
    active: true,
    employee_role_id: 26,
    employee_code: "whatsapp",
    email: "whatsapp",
    city_id: 1,
    reporting_manager_id: manager_id,
    vertical_id: 1,
    access_city_ids: city_ids
  },
  %{
    name: "Cron Bot",
    phone_number: "cron",
    active: true,
    employee_role_id: 26,
    employee_code: "cron",
    email: "cron",
    city_id: 1,
    reporting_manager_id: manager_id,
    vertical_id: 1,
    access_city_ids: city_ids
  },
  %{
    name: "Webhook Bot",
    phone_number: "webhook",
    active: true,
    employee_role_id: 26,
    employee_code: "webhook",
    email: "webhook",
    city_id: 1,
    reporting_manager_id: manager_id,
    vertical_id: 1,
    access_city_ids: city_ids
  }
]

bot_users_seed_data
|> Enum.each(fn bot_user ->
  if BnApis.Accounts.EmployeeCredential
     |> where(phone_number: ^bot_user.phone_number)
     |> Repo.aggregate(:count, :phone_number) == 0 do
    BnApis.Accounts.EmployeeCredential.changeset(%BnApis.Accounts.EmployeeCredential{}, bot_user) |> Repo.insert!()
  end
end)

# ========== add dev_poc_cred ==================

dev_poc_creds_seed_data = [
  %{
    name: "BN Approver",
    phone_number: "9000000000",
    country_code: "+91",
    active: true
  }
]

dev_poc_creds_seed_data
|> Enum.each(fn dev_poc_cred ->
  dev_poc = DeveloperPocCredential.fetch_developer_poc_credential(dev_poc_cred.phone_number, dev_poc_cred.country_code)

  if is_nil(dev_poc) do
    DeveloperPocCredential.changeset(%DeveloperPocCredential{}, dev_poc_cred)
    |> Repo.insert!()
  end
end)

# ========== add BN details in legal_entity ==================
alias BnApis.Stories.LegalEntity

LegalEntity.seed_data()
|> Enum.each(fn data ->
  legalentity = Repo.get_by(LegalEntity, gst: data.gst)

  if is_nil(legalentity) do
    LegalEntity.changeset(%LegalEntity{}, data) |> Repo.insert!()
  else
    if not String.equivalent?(legalentity.billing_address, data.billing_address),
      do: LegalEntity.changeset(legalentity, data) |> Repo.update()
  end
end)

alias BnApis.Schemas.LegalEntityPoc

LegalEntityPoc.seed_data()
|> Enum.each(fn data ->
  legalentity = Repo.get_by(LegalEntityPoc, poc_type: data.poc_type, phone_number: data.phone_number)

  if is_nil(legalentity) do
    LegalEntityPoc.changeset(%LegalEntityPoc{}, data) |> Repo.insert!()
  end
end)
