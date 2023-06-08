defmodule BnApis.Repo.Migrations.AddIndexEmployeePayouts do
  use Ecto.Migration

  def change do
    create index(:employee_payouts, [:rewards_lead_id])
  end
end
