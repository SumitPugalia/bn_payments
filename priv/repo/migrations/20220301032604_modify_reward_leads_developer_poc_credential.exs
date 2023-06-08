defmodule BnApis.Repo.Migrations.ModifyRewardLeadsDeveloperPocCredential do
  use Ecto.Migration

  def change do
    drop constraint(:rewards_leads, "rewards_leads_developer_poc_credential_id_fkey")

    alter table(:rewards_leads) do
      modify :developer_poc_credential_id, references(:developer_poc_credentials),
        null: true,
        from: [references(:developer_poc_credentials), null: false]
    end
  end
end
