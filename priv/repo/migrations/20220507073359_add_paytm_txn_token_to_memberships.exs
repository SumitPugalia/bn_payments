defmodule BnApis.Repo.Migrations.AddPaytmTxnTokenToMemberships do
  use Ecto.Migration

  def change do
    alter table(:memberships) do
      add(:paytm_txn_token, :string)
    end
  end
end
