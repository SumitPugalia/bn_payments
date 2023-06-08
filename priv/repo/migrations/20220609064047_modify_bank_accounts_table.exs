defmodule BnApis.Repo.Migrations.ModifyBankAccountsTable do
  use Ecto.Migration

  def change do
    alter table(:bank_accounts) do
      modify(:account_number, :string, null: false)
      modify(:confirm_account_number, :string, null: false)
    end
  end
end
