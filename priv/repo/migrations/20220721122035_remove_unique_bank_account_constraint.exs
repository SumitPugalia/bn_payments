defmodule BnApis.Repo.Migrations.RemoveUniqueBankAccountConstraint do
  use Ecto.Migration

  def change do
    drop_if_exists index(:bank_accounts, [:account_number, :active],
                     name: :unique_bank_account_number_index
                   )
  end
end
