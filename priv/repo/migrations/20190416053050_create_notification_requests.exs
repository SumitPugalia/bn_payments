defmodule BnApis.Repo.Migrations.CreateNotificationRequests do
  use Ecto.Migration

  def change do
    create table(:notification_requests) do
      add :type, :string
      add :payload, :jsonb
      add :response, :jsonb
      add :sent_to, references(:credentials, on_delete: :nothing)
      add :fcm_id, :string

      timestamps()
    end

    create index(:notification_requests, [:sent_to])
  end
end
