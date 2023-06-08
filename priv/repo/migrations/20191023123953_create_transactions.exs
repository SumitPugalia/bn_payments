defmodule BnApis.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :flat_no, :integer
      add :floor_no, :integer
      add :area, :integer
      add :price, :integer
      add :rent, :integer
      # in months
      add :tenure_for_rent, :integer
      # "rent/resale"
      add :transaction_type, :string

      add :transaction_data_id, references(:transactions_data, on_delete: :nothing)
      add :transaction_building_id, references(:transactions_buildings, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:transactions, [:transaction_data_id])
    create index(:transactions, [:transaction_building_id])
  end
end
