defmodule BnApis.Repo.Migrations.AddPaymentModeToInvoicesTable do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:payment_mode, :string)
    end
  end
end
