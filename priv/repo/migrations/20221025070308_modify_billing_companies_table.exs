defmodule BnApis.Repo.Migrations.ModifyBillingCompaniesTable do
  use Ecto.Migration

  def change do
    alter table(:billing_companies) do
      add(:change_notes, :string)
    end
  end
end
