defmodule BnApis.Repo.Migrations.AddResaleChanges do
  use Ecto.Migration

  def change do
    alter table(:resale_property_posts) do
      add :latest_assisted_property_post_agreement_id,
          references(:assisted_property_post_agreements)

      add :is_assisted, :boolean, default: false
    end
  end
end
