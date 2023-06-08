defmodule BnApis.Repo.Migrations.AddApprovedBySuperIdInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add(:approved_by_super_id, references(:employees_credentials))
    end
  end
end
