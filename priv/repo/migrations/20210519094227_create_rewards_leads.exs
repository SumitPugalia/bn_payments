defmodule BnApis.Repo.Migrations.CreateRewardsLeads do
  use Ecto.Migration

  def change do
    create table(:rewards_leads) do
      add(:name, :string, null: false)
      add(:story_id, references(:stories), null: false)
      add(:developer_poc_credential_id, references(:developer_poc_credentials), null: false)
      add(:broker_id, references(:brokers), null: false)
      timestamps()
    end
  end
end
