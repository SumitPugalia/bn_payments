defmodule BnApis.Repo.Migrations.CreatePocApprovals do
  use Ecto.Migration

  def change do
    create table(:poc_invoice_approvals) do
      add :legal_entity_poc_id, references(:legal_entity_pocs)
      add :invoice_id, references(:invoices)
      add :booking_rewards_lead_id, references(:booking_rewards_leads)
      add :approved_at, :integer, null: false
      add :action, :string, null: false

      timestamps()
    end
  end
end
