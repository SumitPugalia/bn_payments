defmodule BnApis.Repo.Migrations.AlterBuildingsUniqueConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists index(:buildings, [:name, :location], name: :buildings_name_location_index)

    create unique_index(:buildings, [:name, :location, :type],
             name: :buildings_name_location_type_index
           )
  end
end
