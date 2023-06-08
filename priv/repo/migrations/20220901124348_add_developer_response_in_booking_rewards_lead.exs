defmodule BnApis.Repo.Migrations.AddDeveloperResponseInBookingRewardsLead do
  use Ecto.Migration

  def change do
    alter table(:booking_rewards_leads) do
      add :approved_at, :naive_datetime
    end

    alter table(:invoices) do
      add :bonus_amount, :integer
    end
  end
end
