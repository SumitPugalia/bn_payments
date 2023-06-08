defmodule BnApis.Repo.Migrations.DropIndexOnSms do
  use Ecto.Migration

  def change do
    drop_if_exists index(:sms_requests, [:message_status_id])
  end
end
