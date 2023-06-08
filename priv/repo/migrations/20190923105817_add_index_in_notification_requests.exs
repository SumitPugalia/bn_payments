defmodule BnApis.Repo.Migrations.AddIndexInNotificationRequests do
  use Ecto.Migration

  def change do
    create index(:notification_requests, [:request_uuid])
  end
end
