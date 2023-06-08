defmodule BnApis.Repo.Migrations.CreateTransactionsStatuses do
  use Ecto.Migration

  def change do
    create table(:transactions_statuses, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:transactions_statuses, [:name])
  end
end
