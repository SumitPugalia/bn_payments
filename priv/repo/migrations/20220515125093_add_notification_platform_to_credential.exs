defmodule BnApis.Repo.Migrations.AddNotificationPlatformToCredential do
  use Ecto.Migration

  def change do
    alter table(:credentials) do
      add :notification_platform, :string
    end
  end
end
