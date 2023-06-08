defmodule BnApis.Repo.Migrations.AlterCommercialPropertyPostForCoWorking do
  use Ecto.Migration

  def change do
    alter table(:commercial_property_posts) do
      add :tenure, :integer
      add :escalation, :integer
      add :cost_per_seat, :integer
      add :is_include_maintenance, :boolean
      add :internet_charges_per_month, :float
      add :maintenance_cost, :float
    end
  end
end
