defmodule BnApis.Repo.Migrations.AddHoldGstInInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :hold_gst, :boolean, default: false
    end
  end
end
