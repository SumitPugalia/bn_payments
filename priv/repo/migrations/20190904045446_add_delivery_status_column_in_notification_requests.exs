defmodule BnApis.Repo.Migrations.AddDeliveryStatusColumnInNotificationRequests do
  use Ecto.Migration

  def change do
    alter table(:notification_requests) do
      add :uuid, :uuid
      add :client_delivered, :boolean
    end
  end
end
