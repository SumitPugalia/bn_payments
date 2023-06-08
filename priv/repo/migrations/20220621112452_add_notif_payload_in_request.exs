defmodule BnApis.Repo.Migrations.AddNotificationPayload do
  use Ecto.Migration

  def change do
    alter table(:notification_requests) do
      add :notif_payload, :jsonb
    end
  end
end
