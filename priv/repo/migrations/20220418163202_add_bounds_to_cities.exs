defmodule BnApis.Repo.Migrations.AddBoundsToCities do
  use Ecto.Migration

  def change do
    alter table(:cities) do
      add :sw_lat, :float
      add :sw_lng, :float
      add :ne_lat, :float
      add :ne_lng, :float
    end
  end
end
