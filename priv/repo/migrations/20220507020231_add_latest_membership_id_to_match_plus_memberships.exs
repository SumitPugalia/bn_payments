defmodule BnApis.Repo.Migrations.AddLatestMembershipIdToMatchPlusMemberships do
  use Ecto.Migration

  def change do
    alter table(:match_plus_memberships) do
      add(:latest_membership_id, references(:memberships))
    end
  end
end
