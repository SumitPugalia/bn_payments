defmodule BnApis.Repo.Migrations.Add4bCommissionInInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :bn_commission, :float
    end
  end
end
