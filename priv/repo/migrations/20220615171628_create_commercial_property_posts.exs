defmodule BnApis.Repo.Migrations.CreateCommercialPropertyPosts do
  use Ecto.Migration

  def change do
    create table(:commercial_property_posts) do
      add :is_available_for_lease, :boolean, default: true
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :google_maps_url, :string
      add :is_available_for_purchase, :boolean, default: true
      add :chargeable_area, :float
      add :address, :string
      add :carpet_area, :float
      add :premise_type, :integer
      add :efficiency, :integer
      add :building_size, :integer
      add :floor_offer, {:array, :string}, default: []
      add :floor_plate, :integer
      add :unit_number, :string
      add :building_structure, :string
      add :amenities, {:array, :string}, default: []
      add :handover_status, :string
      add :possession_date, :naive_datetime
      add :car_parking_ratio, :string
      add :is_oc_available, :boolean, default: false
      add :oc_target_date, :naive_datetime
      add :layout_plans_available, :boolean, default: false
      add :fit_out_plans_available, :boolean, default: false
      add :ownership_structure, :string
      add :rent, :float
      add :price, :float
      add :property_tax, :float
      add :comman_area_maintenance, :float
      add :car_parking_charges, :float
      add :security_deposit_in_number_of_months, :integer
      add :stamp_duty, :float
      add :registration_charges, :float
      add :fit_out_charges, :float
      add :society_charges, :float
      add :other_charges, :string
      add :status, :string

      add(:building_id, references(:buildings), null: false)
      add(:created_by_id, references(:employees_credentials), null: false)
      add(:approved_by_id, references(:employees_credentials))

      timestamps()
    end
  end
end
