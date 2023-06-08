defmodule BnApis.Repo.Migrations.AmTableChanges do
  use Ecto.Migration

  def change do
    alter table(:assisted_property_post_agreements) do
      add :is_active, :boolean, default: true
    end

    create index(:assisted_property_post_agreements, [:is_active, :resale_property_post_id])
  end
end
