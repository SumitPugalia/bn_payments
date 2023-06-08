defmodule BnApis.Repo.Migrations.CreateTransactionsDistricts do
  use Ecto.Migration

  def change do
    create table(:transactions_districts) do
      add :uuid, :uuid, default: fragment("uuid_generate_v1mc()"), null: false
      add :name, :string
      add :address, :string

      timestamps()
    end

    create index(:transactions_districts, [:name])
  end
end
