defmodule BnApis.Repo.Migrations.AddRegionToCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:region, :string)
    end
  end
end
