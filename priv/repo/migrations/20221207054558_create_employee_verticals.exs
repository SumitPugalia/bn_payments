defmodule BnApis.Repo.Migrations.CreateEmployeeVerticals do
  use Ecto.Migration

  def change do
    create table(:employees_verticals, primary_key: false) do
      add(:id, :integer, primary_key: true)
      add(:name, :string, null: false)
      add(:identifier, :string, null: false)
      add(:active, :boolean, default: true)

      timestamps()
    end

    create unique_index(:employees_verticals, [:name])
  end
end
