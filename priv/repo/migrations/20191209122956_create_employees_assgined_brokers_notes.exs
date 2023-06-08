defmodule BnApis.Repo.Migrations.CreateEmployeesAssginedBrokersNotes do
  use Ecto.Migration

  def change do
    create table(:employees_assigned_brokers_notes) do
      add :employees_assigned_brokers_id,
          references(:employees_assigned_brokers, on_delete: :nothing)

      add :type, :string
      add :data, :string

      timestamps()
    end
  end
end
