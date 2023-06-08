defmodule BnApis.Repo.Migrations.AddFcmInEmployeeCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add :fcm_id, :string
      add :notification_platform, :string
    end
  end
end
