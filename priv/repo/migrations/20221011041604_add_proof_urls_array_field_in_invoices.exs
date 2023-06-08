defmodule BnApis.Repo.Migrations.AddProofUrlsArrayFieldInInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :proof_urls, {:array, :string}
    end
  end
end
