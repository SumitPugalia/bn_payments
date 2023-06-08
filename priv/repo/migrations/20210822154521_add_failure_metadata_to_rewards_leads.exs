defmodule BnApis.Repo.Migrations.AddFailureMetadataToRewardsLeads do
  use Ecto.Migration

  def change do
    alter table(:rewards_lead_statuses) do
      add(:failure_reason_id, :integer)
      add(:failure_note, :string)
    end
  end
end
