defmodule BnApis.Repo.Migrations.AddBankFieldInPaytmWebhooks do
  use Ecto.Migration

  def change do
    alter table(:paytm_webhooks) do
      add :masked_account_number, :string
      add :issuing_bank_logo, :string
      add :issuing_bank, :string
      add :ifsc, :string
    end
  end
end
