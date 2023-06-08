defmodule BnApis.Repo.Migrations.AddTypeAndBookingRewardsLeadIdToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      add :type, :string
      add :booking_rewards_lead_id, references(:booking_rewards_leads, on_delete: :nothing)
    end
  end
end
