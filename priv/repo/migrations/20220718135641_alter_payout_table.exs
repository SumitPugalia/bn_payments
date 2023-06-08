defmodule BnApis.Repo.Migrations.AlterPayoutTable do
  use Ecto.Migration

  def change do
    rename table(:payouts), :razorpay_payout_id, to: :payout_id

    rename table(:employee_payouts), :razorpay_payout_id, to: :payout_id

    alter table(:payouts) do
      add :gateway_name, :string
    end

    alter table(:employee_payouts) do
      add :gateway_name, :string
    end
  end
end
