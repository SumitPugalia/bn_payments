defmodule BnApis.Repo.Migrations.AlterTableCommercialPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add :avg_floor_plate_carpet, :integer
      add :avg_floor_plate_charagable, :integer
      add :property_tax_included_in_price, :boolean, default: false
      add :property_tax_included_in_rent, :boolean, default: false
    end

    alter table(:commercial_site_visits) do
      modify :visit_remarks, :text
      remove :assigned_manager_id
    end
  end
end
