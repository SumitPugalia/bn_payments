defmodule BnApis.Repo.Migrations.AddOcNotAvailableCommercialPropertyPost do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add(:oc_not_available, :boolean, default: false)
    end
  end
end
