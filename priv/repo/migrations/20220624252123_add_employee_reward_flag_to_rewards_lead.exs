defmodule BnApis.Repo.Migrations.AddEmployeeFlagToRewardsLead do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add :release_employee_payout, :boolean, default: true
    end
  end
end
