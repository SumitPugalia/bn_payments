defmodule BnApis.Repo.Migrations.AlterCommercialPropertyPostAddCarCharges do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add(:car_charges_to_be_discussed, :boolean, default: false)
    end
  end
end
