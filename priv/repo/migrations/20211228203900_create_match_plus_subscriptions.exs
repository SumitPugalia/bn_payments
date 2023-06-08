defmodule BnApis.Repo.Migrations.CreateMatchPlusSubscriptions do
  use Ecto.Migration

  def change do
    create table(:match_plus_subscriptions) do
      add(:status_id, :integer, null: false)
      add(:broker_id, references(:brokers), null: false)

      timestamps()
    end
  end
end
