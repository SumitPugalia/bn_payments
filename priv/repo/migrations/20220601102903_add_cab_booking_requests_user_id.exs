defmodule BnApis.Repo.Migrations.RemoveUserId do
  use Ecto.Migration

  def change do
    alter table(:cab_booking_requests) do
      add(:user_id, :integer)
      add(:user_type, :string)
    end
  end
end
