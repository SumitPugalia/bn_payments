defmodule BnApis.Repo.Migrations.CreateMicroMarkets do
  use Ecto.Migration

  def change do
    create table(:micro_markets, primary_key: false) do
      add :id, :integer, primary_key: true
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:micro_markets, [:name])
  end
end
