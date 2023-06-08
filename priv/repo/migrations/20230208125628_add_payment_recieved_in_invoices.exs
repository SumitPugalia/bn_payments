defmodule BnApis.Repo.Migrations.AddPaymentRecievedInInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :payment_received, :boolean
      add :is_tds_valid, :boolean
    end
  end
end
