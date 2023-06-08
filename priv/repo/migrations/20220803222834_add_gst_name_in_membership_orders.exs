defmodule BnApis.Repo.Migrations.AddGstNameInMembershipOrders do
  use Ecto.Migration

  def change do
    alter table(:membership_orders) do
      add(:gst_legal_name, :string)
    end
  end
end
