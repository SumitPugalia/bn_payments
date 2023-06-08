defmodule BnApis.Repo.Migrations.ModifyBillingCompanies do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      modify(:rera_id, :string, null: true, from: :string)
    end
  end
end
