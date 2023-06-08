defmodule BnApis.Repo.Migrations.CreateTransactionsDoctypes do
  use Ecto.Migration

  def change do
    create table(:transactions_doctypes, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:transactions_doctypes, [:name])
  end
end
