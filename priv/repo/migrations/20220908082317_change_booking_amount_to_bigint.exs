defmodule BnApis.Repo.Migrations.ChangeBookingAmountToBigint do
  use Ecto.Migration

  def change do
    alter table(:booking_rewards_leads) do
      modify :agreement_value, :bigint
    end

    alter table(:booking_payment) do
      modify :token_amount, :bigint
    end
  end
end
