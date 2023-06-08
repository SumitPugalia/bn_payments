defmodule BnApis.Repo.Migrations.AddIsEmployeeInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:is_employee, :boolean, default: false)
    end
  end
end
