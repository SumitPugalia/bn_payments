defmodule BnApis.Repo.Migrations.RemoveUniquePanConstraintBillingCompany do
  use Ecto.Migration

  def change do
    drop_if_exists index(:billing_companies, [:pan], name: :unique_pan_billing_companies_index)
  end
end
