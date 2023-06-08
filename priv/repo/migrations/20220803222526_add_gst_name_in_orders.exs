defmodule BnApis.Repo.Migrations.AddGstNameInOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add(:gst_legal_name, :string)
    end
  end
end
