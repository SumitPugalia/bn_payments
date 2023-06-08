defmodule BnApis.Repo.Migrations.AddLatestSubscriptionIdInMatchPlusSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:match_plus_subscriptions) do
      add(:latest_subscription_id, references(:subscriptions))
    end
  end
end
