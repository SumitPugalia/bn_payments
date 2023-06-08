defmodule BnApis.Repo.Migrations.AddLocalityToRawPosts do
  use Ecto.Migration

  def change do
    alter table(:raw_rental_property_posts) do
      add :sub_source, :string
      add :locality, :string
    end

    alter table(:raw_resale_property_posts) do
      add :sub_source, :string
      add :locality, :string
    end
  end
end
