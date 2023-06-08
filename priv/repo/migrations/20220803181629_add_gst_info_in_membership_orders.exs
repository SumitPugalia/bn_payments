defmodule BnApis.Repo.Migrations.AddGstInfoInMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:gst, :string)
      add(:gst_pan, :string)
      add(:gst_constitution, :string)
      add(:gst_address, :string)
    end
  end
end
