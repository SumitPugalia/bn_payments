defmodule BnApis.Repo.Migrations.CreatePayoutStatus do
  use Ecto.Migration

  def change do
    create table(:payout_status) do
      add(:status, :string, null: false)
      add(:rewards_payout_id, references(:payouts), null: false)
      add(:razorpay_data, :map, default: %{})
      timestamps()
    end
  end
end
