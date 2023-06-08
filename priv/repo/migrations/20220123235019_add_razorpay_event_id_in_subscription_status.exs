defmodule BnApis.Repo.Migrations.AddRazorpayEventIdInSubscriptionStatus do
  use Ecto.Migration

  def change do
    alter table(:subscription_status) do
      add(:razorpay_event_id, :string)
    end
  end
end
