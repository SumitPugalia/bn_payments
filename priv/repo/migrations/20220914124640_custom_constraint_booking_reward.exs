defmodule BnApis.Repo.Migrations.CustomConstraintBookingReward do
  use Ecto.Migration

  def change do
    drop unique_index(
           :booking_rewards_leads,
           [:story_id, :booking_form_number, :wing, :unit_number, :deleted],
           name: :booking_rewards_lead_unique_index
         )

    create index(
             :booking_rewards_leads,
             [:story_id, :booking_form_number, :wing, :unit_number, :status_id, :deleted],
             name: :booking_rewards_lead_unique_index,
             where: "status_id in (2,3,4,6, 7) and deleted = false",
             unique: true
           )
  end
end
