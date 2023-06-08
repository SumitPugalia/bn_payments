defmodule BnApis.Repo.Migrations.AddDsaFieldInInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :remarks, :text
      add :rejection_reason, :text
      add :is_billed, :boolean
      add :billing_number, :string
    end
  end
end
