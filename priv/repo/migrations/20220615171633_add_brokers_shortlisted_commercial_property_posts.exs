defmodule BnApis.Repo.Migrations.AddBrokersShortlistedCommercialPropertyPosts do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add :shortlisted_commercial_property_posts, {:array, :map}, default: []
    end
  end
end
