defmodule BnApis.Repo.Migrations.AlterCommercialTables do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      remove :building_structure
      remove :car_parking_ratio
      remove :building_size
      remove :premise_type
      remove :ownership_structure
      add(:is_it_ites_certified, :boolean, default: false)
      add(:ownership_structure, :text)
      add(:premise_type, :string)
      add(:number_of_seats, :integer)
      add(:assigned_manager_id, references(:employees_credentials))
    end

    alter table(:commercial_property_pocs) do
      add :is_active, :boolean, default: true
    end
  end
end
