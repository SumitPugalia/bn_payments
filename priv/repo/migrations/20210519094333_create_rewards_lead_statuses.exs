defmodule BnApis.Repo.Migrations.CreateRewardsLeadStatuses do
  use Ecto.Migration

  def change do
    create table(:rewards_lead_statuses) do
      add(:status_id, :integer, null: false)
      add(:rewards_lead_id, references(:rewards_leads), null: false)
      add(:developer_poc_credential_id, references(:developer_poc_credentials))
      timestamps()
    end
  end
end
