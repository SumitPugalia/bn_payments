defmodule BnApis.Repo.Migrations.DropCreatedByIdFkFromEmployeesAssignedBrokers do
  use Ecto.Migration

  def up do
    execute "ALTER  TABLE employees_assigned_brokers DROP CONSTRAINT employees_assigned_brokers_assigned_by_id_fkey"
  end

  def down do
    execute " ALTER TABLE employees_assigned_brokers ADD FOREIGN KEY (assigned_by_id) REFERENCES employees_credentials(id)"
  end
end
