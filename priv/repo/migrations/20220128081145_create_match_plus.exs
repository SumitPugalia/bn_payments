defmodule BnApis.Repo.Migrations.CreateMatchPlus do
  use Ecto.Migration

  def change do
    create table(:match_plus) do
      add(:status_id, :integer, null: false)
      add(:broker_id, references(:brokers), null: false)
      # add(:latest_order_id, references(:orders))

      timestamps()
    end
  end
end
