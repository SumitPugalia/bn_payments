defmodule BnApis.Repo.Migrations.IndexForPayoutAndRewardsLeadStatuses do
  use Ecto.Migration

  def change do
    create index(:rewards_lead_statuses, [:status_id])
    create index(:payouts, [:rewards_lead_id])
    create index(:payouts, [:status])

    create index(:story_developer_poc_mappings, [:developer_poc_credential_id])
  end
end
