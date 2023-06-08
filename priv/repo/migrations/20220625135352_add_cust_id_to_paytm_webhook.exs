defmodule BnApis.Repo.Migrations.AddCustIdToPaytmWebhook do
  use Ecto.Migration

  def change do
    alter table(:paytm_webhooks) do
      add :cust_id, :string
    end
  end
end
