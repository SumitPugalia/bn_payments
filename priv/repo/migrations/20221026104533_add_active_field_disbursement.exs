defmodule BnApis.Repo.Migrations.AddActiveFieldDisbursement do
  use Ecto.Migration

  def change do
    alter table(:loan_disbursements) do
      add :active, :boolean, default: true
    end
  end
end
