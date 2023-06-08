defmodule BnApis.Repo.Migrations.AddRequestUuidInNotifications do
  use Ecto.Migration

  def change do
    alter table(:notification_requests) do
      add :request_uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
    end
  end
end
