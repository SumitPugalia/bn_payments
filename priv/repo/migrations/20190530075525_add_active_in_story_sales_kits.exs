defmodule BnApis.Repo.Migrations.AddActiveInStorySalesKits do
  use Ecto.Migration

  def change do
    alter table(:stories_sales_kits) do
      add :active, :boolean, default: true
    end
  end
end
