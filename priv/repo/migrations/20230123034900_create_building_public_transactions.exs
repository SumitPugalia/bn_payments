defmodule BnApis.Repo.Migrations.CreateBuildingPublicTransactions do
  use Ecto.Migration

  def change do
    create table(:public_transactions) do
      add(:wing, :string)
      add(:area, :integer)
      add(:price, :integer)
      add(:unit_number, :string)
      add(:transaction_type, :string)
      add(:transaction_date, :naive_datetime)

      add(:configuration_type_id, references(:posts_configuration_types), null: false)
      add(:building_id, references(:buildings), null: false)

      timestamps()
    end
  end
end
