defmodule BnApis.Repo.Migrations.AlterCommercialFields do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      remove :possession_date
      remove :oc_target_date
      remove :rent
      remove :fit_out_charges
      remove :car_parking_charges
      add(:possession_date, :integer)
      add(:oc_target_date, :integer)
      add(:is_ready_to_move, :boolean, default: true)
      add(:property_tax_per_month, :float)
      add(:common_area_maintenance_per_month, :float)
      add(:car_parking_slot_charge_per_month, :float)
      add(:car_parking_slot_charge, :float)
      add(:rent_per_month, :float)
      add(:fit_out_charges_per_month, :float)
    end

    alter table(:commercial_site_visits) do
      remove :uuid
      remove :visit_status
      add(:visit_status, :string)
    end
  end
end
