defmodule BnApis.Repo.Migrations.AddCreatedAtInPayouts do
  use Ecto.Migration

  def change do
    alter table(:payouts) do
      add(:created_at, :integer)
    end
  end
end
