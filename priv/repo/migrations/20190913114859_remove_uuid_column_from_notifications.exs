defmodule BnApis.Repo.Migrations.RemoveUuidColumnFromNotifications do
  use Ecto.Migration

  def change do
    alter table(:notification_requests) do
      remove :uuid
    end
  end
end
