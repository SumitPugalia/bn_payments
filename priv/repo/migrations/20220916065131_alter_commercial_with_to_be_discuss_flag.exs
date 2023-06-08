defmodule BnApis.Repo.Migrations.AlterCommercialWithToBeDiscussFlag do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add :property_tax_per_month_to_be_discussed, :boolean, default: false
      add :security_deposit_to_be_discussed, :boolean, default: false
      add :cam_per_month_to_be_discussed, :boolean, default: false
      add :cpsc_per_month_to_be_discussed, :boolean, default: false
    end
  end
end
