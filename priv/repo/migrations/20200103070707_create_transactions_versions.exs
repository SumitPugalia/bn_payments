defmodule BnApis.Repo.Migrations.CreateTransactionsVersions do
  use Ecto.Migration

  def change do
    create table(:transactions_versions) do
      add :version_id, :integer
      add :flat_no, :string
      add :floor_no, :integer
      add :area, :decimal
      add :price, :integer
      add :rent, :integer
      # in months
      add :tenure_for_rent, :integer
      # "rent/resale"
      add :transaction_type, :string
      add :registration_date, :naive_datetime

      add :edited_by_id, references(:employees_credentials, on_delete: :nothing)
      add :transaction_id, references(:transactions, on_delete: :nothing)
      add :transaction_building_id, references(:transactions_buildings, on_delete: :nothing)

      timestamps()
    end

    create index(:transactions_versions, [:edited_by_id])
    create index(:transactions_versions, [:transaction_id])
    create index(:transactions_versions, [:transaction_building_id])
  end
end
