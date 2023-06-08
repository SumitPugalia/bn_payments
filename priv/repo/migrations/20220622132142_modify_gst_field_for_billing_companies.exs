defmodule BnApis.Repo.Migrations.ModifyGstFieldForBillingCompanies do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      modify(:gst, :string, null: true, from: :string)
    end
  end
end
