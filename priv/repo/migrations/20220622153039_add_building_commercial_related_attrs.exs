defmodule BnApis.Repo.Migrations.AddBuildingAttrsAndAlterCommercial do
  use Ecto.Migration

  def change do
    alter table(:buildings) do
      add(:type, :string)
      add(:structure, :text)
      add(:car_parking_ratio, :string)
      add(:total_development_size, :integer)
      add(:grade, :string)
    end
  end
end
