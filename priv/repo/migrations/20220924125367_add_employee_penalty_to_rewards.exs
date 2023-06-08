defmodule BnApis.Repo.Migrations.AddEmployeePenaltyToRewards do
  use Ecto.Migration

  def change do
    alter table(:rewards_leads) do
      add(:has_employee_penalty, :boolean, default: false)
    end
  end
end
