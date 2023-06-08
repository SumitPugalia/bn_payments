defmodule BnApis.Repo.Migrations.AlterCommercialPropertyPost do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add(:property_tax_to_be_discussed, :boolean, default: false)
      add(:common_area_maintenance_to_be_discussed, :boolean, default: false)
    end
  end
end
