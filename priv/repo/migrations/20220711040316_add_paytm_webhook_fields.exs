defmodule BnApis.Repo.Migrations.AddPaytmWebhookFields do
  use Ecto.Migration

  def change do
    alter table(:paytm_webhooks) do
      add :txn_date_time, :string
      add :merc_unq_ref, :string
      add :retries_left, :string
      add :last_retry_done_attempted_time, :string
      add :retry_allowed, :string
      add :error_message, :string
      add :error_code, :string
      add :total_retry_count, :string
    end
  end
end
