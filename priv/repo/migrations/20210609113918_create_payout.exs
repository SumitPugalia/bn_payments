defmodule BnApis.Repo.Migrations.CreatePayout do
  use Ecto.Migration

  def change do
    create table(:payouts) do
      add(:razorpay_payout_id, :string, null: false)
      add(:status, :string, null: false)
      add(:account_number, :string, null: false)
      add(:fund_account_id, :string, null: false)
      add(:amount, :float, null: false)
      add(:purpose, :string, null: false)
      add(:mode, :string, null: false)
      add(:reference_id, :string)
      add(:utr, :string)
      add(:currency, :string)
      add(:rewards_lead_name, :string)
      add(:broker_phone_number, :string)
      add(:story_name, :string)
      add(:developer_poc_name, :string)
      add(:developer_poc_number, :string)
      add(:rewards_lead_id, references(:rewards_leads), null: false)
      add(:broker_id, references(:brokers), null: false)
      add(:story_id, references(:stories), null: false)

      add(:developer_poc_credential_id, references(:developer_poc_credentials), null: false)

      timestamps()
    end
  end
end
