defmodule BnApis.Repo.Migrations.AddFlagsInBrokers do
  use Ecto.Migration

  def change do
    alter table(:brokers) do
      add(:is_cab_booking_enabled, :boolean, default: false)
      add(:is_invoicing_enabled, :boolean, default: false)
    end
  end
end
