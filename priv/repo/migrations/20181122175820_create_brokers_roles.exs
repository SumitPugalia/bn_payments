defmodule BnApis.Repo.Migrations.CreateBrokersRoles do
  use Ecto.Migration

  def change do
    create table(:brokers_roles, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:brokers_roles, [:name])
  end
end
