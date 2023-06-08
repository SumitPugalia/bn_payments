defmodule BnApis.Repo.Migrations.CreateSmsRequestsTable do
  use Ecto.Migration

  def change do
    create table(:sms_requests) do
      add :message_sid, :string, null: false
      add :message_status_id, :integer
      add :to, :string, null: false
      add :body, :string

      timestamps()
    end

    create unique_index(:sms_requests, [:message_status_id])
    create index(:sms_requests, [:to])
  end
end
