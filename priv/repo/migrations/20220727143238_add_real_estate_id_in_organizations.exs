defmodule BnApis.Repo.Migrations.AddRealEstateIdInOrganizations do
  use Ecto.Migration

  def change do
    alter table("organizations") do
      add :real_estate_id, :integer
    end

    create unique_index(:organizations, [:real_estate_id])
  end
end
