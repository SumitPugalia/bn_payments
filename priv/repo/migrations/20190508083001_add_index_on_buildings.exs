defmodule BnApis.Repo.Migrations.AddIndexOnBuildings do
  use Ecto.Migration

  def change do
    create unique_index(:buildings, [:name, :location])
  end
end
