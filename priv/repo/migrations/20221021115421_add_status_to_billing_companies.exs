defmodule BnApis.Repo.Migrations.AddStatusToBillingCompanies do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      add(:status, :string)
    end
  end
end
