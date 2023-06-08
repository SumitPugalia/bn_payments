defmodule BnApis.Repo.Migrations.Add_IsAvailableForRerouting do
  use Ecto.Migration

  def change do
    alter table(:cab_vehicles) do
      add(:is_available_for_rerouting, :boolean, default: false)
    end
  end
end
