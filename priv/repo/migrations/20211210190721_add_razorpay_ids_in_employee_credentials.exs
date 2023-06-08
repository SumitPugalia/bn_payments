defmodule BnApis.Repo.Migrations.AddRazorpayIdsInEmployeeCredentials do
  use Ecto.Migration

  def change do
    alter table(:employees_credentials) do
      add(:razorpay_contact_id, :string)
      add(:razorpay_fund_account_id, :string)
    end
  end
end
