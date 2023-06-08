defmodule BnApis.Repo.Migrations.CreateEmployeesRoles do
  use Ecto.Migration

  def change do
    create table(:employees_roles, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:employees_roles, [:name])
  end
end
