defmodule BnApis.Repo.Migrations.DeleteProofUrlFieldInInvoices do
  use Ecto.Migration

  def up do
    alter table(:invoices) do
      remove :proof_url
    end
  end

  def down do
    alter table(:invoices) do
      add :proof_url, :string
    end
  end
end
