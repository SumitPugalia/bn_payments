defmodule BnApis.Repo.Migrations.AddIndexOnMessageSid do
  use Ecto.Migration

  def change do
    create unique_index(:sms_requests, [:message_sid])
  end
end
