defmodule BnApis.Repo.Migrations.AddFloorInRawResale do
  use Ecto.Migration

  def change do
    alter table(:raw_resale_property_posts) do
      add(:floor, :string)
    end
  end
end
