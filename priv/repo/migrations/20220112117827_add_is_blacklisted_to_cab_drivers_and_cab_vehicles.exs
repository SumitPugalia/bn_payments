defmodule BnApis.Repo.Migrations.AddIsBlacklistedToCabDriversAndCabVehicles do
  use Ecto.Migration

  def change do
    alter table(:cab_drivers) do
      add(:is_blacklisted, :boolean, default: false)
    end

    alter table(:cab_vehicles) do
      add(:is_blacklisted, :boolean, default: false)
    end
  end
end
