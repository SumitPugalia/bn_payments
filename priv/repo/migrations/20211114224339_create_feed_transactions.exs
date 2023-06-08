defmodule BnApis.Repo.Migrations.CreateFeedTransactions do
  use Ecto.Migration

  def change do
    create table(:feed_transactions) do
      add(:uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false)
      add(:area_type, :string)
      add(:transaction_type, :string)
      add(:comps_id, :integer)
      add(:feed_locality_id, :integer)
      add(:feed_locality_name, :string)
      add(:feed_project_id, :integer)
      add(:feed_project_name, :string)
      add(:consideration, :float)
      add(:converted_area, :float)
      add(:floor, :integer)
      add(:registration_date, :naive_datetime)
      add(:rent_duration, :string)
      add(:tower, :string)
      add(:wing, :string)

      timestamps()
    end

    create(unique_index(:feed_transactions, [:comps_id]))
  end
end
