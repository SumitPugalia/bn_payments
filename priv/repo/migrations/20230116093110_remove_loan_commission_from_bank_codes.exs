defmodule BnApis.Repo.Migrations.RemoveLoanCommissionFromBankCodes do
  use Ecto.Migration

  def change do
    alter table(:bank_bn_codes) do
      remove :commission_percent
    end
  end
end
