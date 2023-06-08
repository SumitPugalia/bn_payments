defmodule BnApis.Repo.Migrations.AddSnoozeInEmployeesAssignedBrokers do
  use Ecto.Migration

  def change do
    alter table(:employees_assigned_brokers) do
      add :snoozed, :boolean, default: false
      add :snoozed_till, :naive_datetime
    end
  end
end
