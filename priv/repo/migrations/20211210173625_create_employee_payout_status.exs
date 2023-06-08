defmodule BnApis.Repo.Migrations.CreateEmployeePayoutStatus do
  use Ecto.Migration

  def change do
    create table(:employee_payout_status) do
      add(:status, :string, null: false)
      add(:rewards_employee_payout_id, references(:employee_payouts), null: false)
      add(:razorpay_data, :map, default: %{})
      timestamps()
    end
  end
end
