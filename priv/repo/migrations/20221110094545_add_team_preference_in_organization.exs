defmodule BnApis.Repo.Migrations.AddTeamPreferenceInOrganization do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :team_upi_cred_uuid, :uuid
      add :members_can_add_billing_company, :boolean, default: true
    end
  end
end
