defmodule BnApis.Repo.Migrations.AddReferenceForPocApprovals do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :poc_approvals_id, references(:poc_invoice_approvals)
    end

    alter table(:booking_rewards_leads) do
      add :poc_approvals_id, references(:poc_invoice_approvals)
    end
  end
end
