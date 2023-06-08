defmodule BnApis.Repo.Migrations.AddPdfFieldsInBookingRewardsLeadTable do
  use Ecto.Migration

  def change do
    alter table(:booking_rewards_leads) do
      add(:booking_rewards_pdf, :string)
      add(:developer_response_pdf, :string)
    end
  end
end
