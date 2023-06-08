defmodule BnApis.Repo.Migrations.CreateCabDrivers do
  use Ecto.Migration

  def change do
    create table(:cab_drivers) do
      add :name, :string, null: false
      add :phone_number, :string, null: false
      add(:cab_operator_id, references(:cab_operators), null: false)
      timestamps()
    end

    create unique_index(:cab_drivers, [:phone_number])
  end
end
